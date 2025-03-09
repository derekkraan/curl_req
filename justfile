default: test

watch +target:
  watchexec -r --clear=reset -w . --project-origin=. --stop-timeout=0 {{target}} 

test target='':
  watchexec -r --clear=reset -w . --project-origin=. --stop-timeout=0 mix test --warnings-as-errors --all-warnings {{target}}
