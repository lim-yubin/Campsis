"""관문 3 검증 --- Embedding 모델을 Core ML로 변환해 ANE에서 돌릴 수 있는가.

PRD §11.5의 세 번째 관문이다. 성적이 좋은 모델을 고른 뒤 실행 불가를
발견하면 손실이 크므로 선정과 병행해서 확인한다.

임베딩은 모든 캡처마다 실행되므로(PRD §11.10 Capture 경로) ANE 실행 여부가
배터리에 직접 영향을 준다. GPU로 떨어지면 상시 동작하는 메뉴바 앱에서
전력 부담이 커진다.

확인 항목
  1. 변환 성공 여부
  2. PyTorch와 수치 일치 (코사인 유사도) --- 변환은 성공해도 결과가
     달라지면 재색인 없이 교체할 수 없다
  3. compute unit별 지연 --- ANE가 실제로 쓰이는지 간접 확인
  4. 모델 크기 --- CDN 배포 비용과 디스크 사용량 (PRD §19.4)

사용:
  uv run python -m src.coreml_check --models bge-m3 pixie-rune
  uv run python -m src.coreml_check --models bge-m3 --seq-len 256
"""

import argparse
import shutil
import time
from pathlib import Path

import numpy as np
import torch

from . import candidates

OUT_DIR = Path(__file__).resolve().parent.parent / "build" / "coreml"


def _register_missing_ops() -> None:
    """coremltools 프런트엔드에 없는 연산을 채운다.

    transformers 5.x가 어텐션 마스크를 만들 때 `new_ones`를 쓰는데
    coremltools 9.0에 변환 규칙이 없다. 모델 아키텍처의 한계가 아니라
    툴체인 공백이므로, 관문 3 판정을 위해 여기서 메운다.

    Swift 쪽에서는 이 문제가 없다. 변환은 개발 시점에 한 번만 하고
    산출물(.mlpackage)만 앱에 들어간다.
    """
    from coremltools.converters.mil import Builder as mb
    from coremltools.converters.mil.frontend.torch.ops import _get_inputs
    from coremltools.converters.mil.frontend.torch.torch_op_registry import (
        _TORCH_OPS_REGISTRY,
        register_torch_op,
    )
    from coremltools.converters.mil.frontend.torch.utils import (
        NUM_TO_NUMPY_DTYPE,
    )
    from coremltools.converters.mil.mil import types

    if "new_ones" in _TORCH_OPS_REGISTRY.name_to_func_mapping:
        return

    @register_torch_op
    def new_ones(context, node):
        # aten::new_ones(self, size, dtype, layout, device, pin_memory)
        inputs = _get_inputs(context, node, expected=6)
        source, size, dtype_arg = inputs[0], inputs[1], inputs[2]

        if dtype_arg is not None and dtype_arg.val is not None:
            nptype = NUM_TO_NUMPY_DTYPE[int(dtype_arg.val)]
        else:
            nptype = types.nptype_from_builtin(source.dtype)

        if size.val is None:
            # shape이 실행 시점에 정해지는 경우. fill로 만들고 형변환한다.
            filled = mb.fill(shape=size, value=1.0)
            result = mb.cast(
                x=filled, dtype=types.builtin_to_string(source.dtype), name=node.name
            )
        else:
            # shape이 상수다. size가 비면 스칼라이며 fill은 빈 shape를 받지
            # 못하므로 상수로 내보낸다. transformers의 마스크 생성이 이 경로다.
            shape = tuple(int(d) for d in np.atleast_1d(size.val))
            result = mb.const(val=np.ones(shape, dtype=nptype), name=node.name)

        context.add(result)


class PooledEncoder(torch.nn.Module):
    """CLS 풀링 + L2 정규화까지 포함한 래퍼.

    풀링과 정규화를 Swift에서 다시 구현하면 미묘하게 어긋날 수 있다.
    그래프에 넣어 두면 Core ML 출력이 그대로 검색에 쓸 수 있는 벡터가 된다.
    """

    def __init__(self, backbone: torch.nn.Module, pooling: str):
        super().__init__()
        self.backbone = backbone
        self.pooling = pooling

    def forward(self, input_ids, attention_mask):
        out = self.backbone(input_ids=input_ids, attention_mask=attention_mask)
        hidden = out.last_hidden_state

        if self.pooling == "cls":
            pooled = hidden[:, 0]
        else:
            mask = attention_mask.unsqueeze(-1).to(hidden.dtype)
            pooled = (hidden * mask).sum(dim=1) / mask.sum(dim=1).clamp(min=1e-9)

        return torch.nn.functional.normalize(pooled, p=2, dim=1)


def _pooling_mode(st_model) -> str:
    """모델이 선언한 풀링 방식을 읽는다.

    기본값으로 넘기지 않는다. 풀링을 틀리면 변환은 성공하고 벡터만 조용히
    달라지므로, 알 수 없으면 즉시 실패해야 한다.

    sentence-transformers 6.x는 `pooling_mode` 문자열 하나를 쓴다. 5.x 이하는
    `pooling_mode_cls_token` 같은 개별 불리언이었다. 둘 다 지원한다.
    """
    for module in st_model.modules():
        if type(module).__name__ != "Pooling":
            continue

        mode = getattr(module, "pooling_mode", None)
        if isinstance(mode, str):
            if mode in ("cls", "mean"):
                return mode
            raise SystemExit(f"지원하지 않는 풀링 방식: {mode!r}")

        flags = {
            "cls": getattr(module, "pooling_mode_cls_token", None),
            "mean": getattr(module, "pooling_mode_mean_tokens", None),
        }
        if any(v is None for v in flags.values()):
            raise SystemExit(
                "Pooling 모듈에서 풀링 방식을 읽을 수 없다. "
                "sentence-transformers 버전이 바뀐 것으로 보인다."
            )
        for name, enabled in flags.items():
            if enabled:
                return name
        raise SystemExit(f"알 수 없는 풀링 조합: {flags}")

    raise SystemExit("Pooling 모듈을 찾지 못했다.")


def _dir_size_mb(path: Path) -> float:
    total = sum(f.stat().st_size for f in path.rglob("*") if f.is_file())
    return total / (1024 * 1024)


def _bench(mlmodel, feed: dict, runs: int = 10) -> float:
    """중간값 지연(ms). 평균은 첫 실행의 준비 비용에 흔들린다."""
    mlmodel.predict(feed)  # warmup
    times = []
    for _ in range(runs):
        started = time.perf_counter()
        mlmodel.predict(feed)
        times.append((time.perf_counter() - started) * 1000)
    return float(np.median(times))


def check(
    cand: candidates.Candidate, seq_len: int, keep: bool, quantize: int | None
) -> dict:
    import coremltools as ct
    from sentence_transformers import SentenceTransformer

    _register_missing_ops()

    result: dict = {"key": cand.key, "seq_len": seq_len}
    print(f"\n{'=' * 78}\n[{cand.key}] {cand.model_id}\n{'=' * 78}")

    st = SentenceTransformer(cand.model_id, device="cpu", trust_remote_code=True)
    backbone = st[0].auto_model
    pooling = _pooling_mode(st)
    n_params = sum(p.numel() for p in backbone.parameters())
    print(f"파라미터 {n_params / 1e6:.0f}M, 풀링 {pooling}, 아키텍처 "
          f"{type(backbone).__name__}")
    result["params_m"] = n_params / 1e6
    result["arch"] = type(backbone).__name__

    wrapper = PooledEncoder(backbone, pooling).eval()
    ids = torch.randint(5, 1000, (1, seq_len), dtype=torch.int32)
    mask = torch.ones((1, seq_len), dtype=torch.int32)

    with torch.no_grad():
        reference = wrapper(ids, mask).numpy()
    result["dim"] = int(reference.shape[1])

    print("추적(trace) 중 ...")
    try:
        with torch.no_grad():
            traced = torch.jit.trace(wrapper, (ids, mask), strict=False)
    except Exception as exc:
        print(f"  실패: {type(exc).__name__}: {exc}")
        result["status"] = "trace 실패"
        result["error"] = f"{type(exc).__name__}: {exc}"
        return result

    print("Core ML 변환 중 (fp16, 고정 shape) ...")
    started = time.time()
    try:
        mlmodel = ct.convert(
            traced,
            inputs=[
                ct.TensorType(name="input_ids", shape=(1, seq_len), dtype=np.int32),
                ct.TensorType(
                    name="attention_mask", shape=(1, seq_len), dtype=np.int32
                ),
            ],
            outputs=[ct.TensorType(name="embedding")],
            # ANE는 fp16만 쓴다. fp32로 두면 ANE 배치가 되지 않는다.
            compute_precision=ct.precision.FLOAT16,
            # mlprogram이 ANE 배치에 유리하다.
            convert_to="mlprogram",
            minimum_deployment_target=ct.target.macOS15,
        )
    except Exception as exc:
        print(f"  실패: {type(exc).__name__}: {exc}")
        result["status"] = "변환 실패"
        result["error"] = f"{type(exc).__name__}: {exc}"
        return result

    print(f"  변환 완료 {time.time() - started:.0f}s")

    if quantize:
        # fp16 1GB는 첫 실행 다운로드로 부담이 크다(PRD §19.4). 가중치의 절반
        # 가까이가 vocab 250K 임베딩 테이블이므로 양자화 효과가 크다.
        # 검색 품질에 영향이 있는지는 코사인 일치로 확인한다.
        import coremltools.optimize.coreml as cto

        print(f"  int{quantize} 양자화 중 ...")
        config = cto.OptimizationConfig(
            global_config=cto.OpLinearQuantizerConfig(
                mode="linear_symmetric", dtype=f"int{quantize}"
            )
        )
        mlmodel = cto.linear_quantize_weights(mlmodel, config=config)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    suffix = f"-int{quantize}" if quantize else "-fp16"
    package = OUT_DIR / f"{cand.key}-seq{seq_len}{suffix}.mlpackage"
    if package.exists():
        shutil.rmtree(package)
    mlmodel.save(str(package))
    size_mb = _dir_size_mb(package)
    result["size_mb"] = size_mb
    print(f"  크기 {size_mb:.0f}MB")

    feed = {
        "input_ids": ids.numpy().astype(np.int32),
        "attention_mask": mask.numpy().astype(np.int32),
    }

    # compute unit을 바꿔 지연을 비교한다. ALL과 CPU_ONLY 격차가 크면
    # 가속기(ANE 또는 GPU)가 실제로 쓰인다는 뜻이다.
    units = {
        "ALL (ANE 우선)": ct.ComputeUnit.ALL,
        "CPU + ANE": ct.ComputeUnit.CPU_AND_NE,
        "CPU only": ct.ComputeUnit.CPU_ONLY,
    }
    latency: dict[str, float] = {}
    parity: float | None = None

    for label, unit in units.items():
        try:
            loaded = ct.models.MLModel(str(package), compute_units=unit)
            out = loaded.predict(feed)["embedding"]
            ms = _bench(loaded, feed)
            latency[label] = ms
            if parity is None:
                cos = float(
                    np.dot(reference[0], out[0])
                    / (np.linalg.norm(reference[0]) * np.linalg.norm(out[0]))
                )
                parity = cos
            print(f"  {label:<16} {ms:>7.1f}ms")
        except Exception as exc:
            print(f"  {label:<16} 실패: {type(exc).__name__}")
            latency[label] = float("nan")

    result["latency"] = latency
    result["parity"] = parity
    result["status"] = "성공"
    result["quantize"] = quantize

    if parity is not None:
        print(f"\n  PyTorch 대비 코사인 유사도 {parity:.6f}")
        if parity < 0.999:
            print(
                "  경고: 수치가 어긋난다. fp16 변환 오차가 검색 품질에 영향을\n"
                "        주는지 평가셋으로 재확인해야 한다."
            )

    if not keep:
        shutil.rmtree(package, ignore_errors=True)

    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Core ML 변환 검증 (관문 3)")
    parser.add_argument("--models", nargs="+", default=["bge-m3"])
    parser.add_argument(
        "--seq-len",
        type=int,
        default=512,
        help="고정 시퀀스 길이. ANE는 동적 shape에 불리하다.",
    )
    parser.add_argument(
        "--keep", action="store_true", help="변환된 .mlpackage를 남긴다"
    )
    parser.add_argument(
        "--quantize",
        type=int,
        choices=[4, 8],
        default=None,
        help="가중치 양자화 비트. 크기를 줄이지만 수치 일치를 확인해야 한다.",
    )
    args = parser.parse_args()

    cands = candidates.resolve(args.models)
    results = [
        check(c, args.seq_len, args.keep, args.quantize) for c in cands
    ]

    print("\n" + "=" * 78)
    print(f"관문 3 요약 (seq_len={args.seq_len})")
    print("=" * 78)
    header = (
        f"{'key':<16}{'아키텍처':<22}{'크기':>9}{'ALL':>10}{'CPU':>10}{'일치':>10}"
    )
    print(header)
    print("-" * 78)
    for r in results:
        if r["status"] != "성공":
            print(f"{r['key']:<16}{r.get('arch', '?'):<22}{r['status']}")
            continue
        lat = r["latency"]
        all_ms = lat.get("ALL (ANE 우선)", float("nan"))
        cpu_ms = lat.get("CPU only", float("nan"))
        print(
            f"{r['key']:<16}{r['arch']:<22}{r['size_mb']:>8.0f}M"
            f"{all_ms:>9.1f}ms{cpu_ms:>9.1f}ms{r['parity']:>10.5f}"
        )

    print(
        "\n판정 기준\n"
        "  - 변환 성공 + 코사인 일치 0.999 이상이면 관문 3 통과\n"
        "  - ALL이 CPU only보다 뚜렷하게 빠르면 가속기가 쓰이는 것\n"
        "  - 크기는 CDN 배포 비용과 직결된다 (PRD §19.4)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
