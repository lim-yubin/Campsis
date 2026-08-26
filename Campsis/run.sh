#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

case "${1:-run}" in
  build)
    echo "▶ Building..."
    xcodebuild -project "$PROJECT_DIR/Campsis.xcodeproj" \
      -scheme Campsis -configuration Debug \
      SYMROOT="$BUILD_DIR" -skipPackagePluginValidation -skipMacroValidation -quiet
    echo "✓ Build succeeded: $BUILD_DIR/Debug/Campsis.app"
    ;;

  run)
    echo "▶ Building..."
    xcodebuild -project "$PROJECT_DIR/Campsis.xcodeproj" \
      -scheme Campsis -configuration Debug \
      SYMROOT="$BUILD_DIR" -skipPackagePluginValidation -skipMacroValidation -quiet
    echo "✓ Build succeeded"

    if pkill -x Campsis 2>/dev/null; then
      sleep 1
      while pgrep -x Campsis >/dev/null 2>&1; do sleep 0.3; done
    fi

    echo "▶ Launching Campsis..."
    if ! open "$BUILD_DIR/Debug/Campsis.app" 2>/dev/null; then
      "$BUILD_DIR/Debug/Campsis.app/Contents/MacOS/Campsis" &
      disown
    fi
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
      SYMROOT="$BUILD_DIR" -skipPackagePluginValidation -skipMacroValidation -quiet
    echo "✓ All tests passed"
    ;;

  *)
    echo "Usage: $0 {build|run|stop|clean|test}"
    exit 1
    ;;
esac
