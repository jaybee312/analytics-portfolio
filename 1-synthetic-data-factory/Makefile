# Quick make targets for local dev
.PHONY: run clean test

run:
	Rscript R/main.R --dataset marketing --config config/datasets/marketing.yml --out outputs/marketing --seed 123

clean:
	rm -rf outputs/marketing

test:
	Rscript tests/test_marketing.R
