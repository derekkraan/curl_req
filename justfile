default: watch

watch:
  watchexec -r --clear=reset -w . --project-origin=. --stop-timeout=0 mix test --warnings-as-errors --all-warnings
