#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

case "${1:-run}" in
  build)
    echo "▶ Building..."
    xcodebuild -project "$PROJECT_DIR/Campsis.xcodeproj" \
      -scheme Campsis -configuration Debug \
      SYMROOT="$BUILD_DIR" -quiet
    echo "✓ Build succeeded: $BUILD_DIR/Debug/Campsis.app"
    ;;

  run)
    echo "▶ Building..."
    xcodebuild -project "$PROJECT_DIR/Campsis.xcodeproj" \
      -scheme Campsis -configuration Debug \
      SYMROOT="$BUILD_DIR" -quiet
    echo "✓ Build succeeded"

    pkill -x Campsis 2>/dev/null && sleep 0.5 || true

    echo "▶ Launching Campsis..."
    open "$BUILD_DIR/Debug/Campsis.app"
    echo "✓ Running (menu bar icon should appear)"
    ;;

  stop)
    if pkill -x Campsis 2>/dev/null; then
      echo "✓ Campsis terminated"
    else
      echo "✗ Campsis is not running"
    fi
    ;;

  clean)
    rm -rf "$BUILD_DIR"
    echo "✓ Build directory removed"
    ;;

  test)
    echo "▶ Running tests..."
    xcodebuild -project "$PROJECT_DIR/Campsis.xcodeproj" \
      -scheme Campsis -configuration Debug \
      -only-testing:CampsisTests test \
      SYMROOT="$BUILD_DIR" -quiet
    echo "✓ All tests passed"
    ;;

  *)
    echo "Usage: $0 {build|run|stop|clean|test}"
    exit 1
    ;;
esac
