

tar:
	tar cfv ../cloudmaster.tar -C.. --exclude=\.svn cloudmaster

unit-test:   
	cd $(AWS_HOME)/test; suite

run:
	cd $(AWS_HOME)/app; run-cloudmaster


request-prime:
	cd $(AWS_HOME)/example/primes; feed-primes-queue

request-fib:
	cd $(AWS_HOME)/examples/fibonacci; run-client
