#!/usr/bin/env bash

cm-directory := $(shell pwd)
cm-dirname   := $(shell dirname ${cm-directory})
cm-basename  := $(shell basename ${cm-directory})

tmp-dir := $(shell mktemp -d /tmp/XXXXXXXXX)

tar:
	cp -a ${cm-directory} ${tmp-dir}/cloudmaster
	tar cjf ${cm-dirname}/cloudmaster-${cm-basename}-$(shell date +%Y%m%d).tbz2 -C ${tmp-dir} --exclude=\.svn --exclude=\.git cloudmaster
	rm -rf ${tmp-dir}
	
unit-test:   
	cd $(AWS_HOME)/test; suite

run:
	cd $(AWS_HOME)/app; run-cloudmaster


request-prime:
	cd $(AWS_HOME)/example/primes; feed-primes-queue

request-fib:
	cd $(AWS_HOME)/examples/fibonacci; run-client
