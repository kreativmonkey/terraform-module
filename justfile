default:
    @just --list

[group('format')]
fmt:
    tofu fmt -recursive .

[group('format')]
fmt-check:
    tofu fmt -check -recursive .

[group('validate')]
init:
    tofu -chdir=talos-cluster init -backend=false

[group('validate')]
validate: init
    tofu -chdir=talos-cluster validate

[group('test')]
test: init
    tofu -chdir=talos-cluster test

[group('validate')]
check: fmt-check validate test
