
.PHONY: all lint kubeval test package debug debug-ui

all: lint test package

lint:
	helm lint charts/onechart/
	helm lint charts/cron-job/

test:
	helm dependency update charts/onechart
	helm unittest charts/onechart

	helm dependency update charts/cron-job
	helm unittest charts/cron-job

package:
	helm dependency update charts/onechart
	helm package charts/onechart
	mv onechart*.tgz docs

	helm dependency update charts/cron-job
	helm package charts/cron-job
	mv cron-job*.tgz docs

debug:
	helm dependency update charts/onechart
	helm template my-release charts/onechart/ -f values.yaml --debug

debug-cron-job:
	helm dependency update charts/cron-job
	helm template charts/cron-job/ -f values-cron-job.yaml --debug
