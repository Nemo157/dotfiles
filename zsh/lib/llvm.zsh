function () {
  # In order of inverse priority
  symbolizers=(
    "/usr/bin/llvm-symbolizer-3.4"
  )
  for symbolizer in $symbolizers
    if [[ -e "$symbolizer" ]] {
      export ASAN_SYMBOLIZER_PATH="$symbolizer"
    }
}
