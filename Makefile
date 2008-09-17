

tar:
	cd $AWS_HOME/..
	tar cfv cloudmaster.tar `find cloudmaster|egrep -v \.svn`

unit-test:   
	cd $(AWS_HOME)/test; suite

run:
	cd $(AWS_HOME)/app; run-cloudmaster


request-prime:
	cd $(AWS_HOME)/example/primes; feed-primes-queue

request-fib:
	cd $(AWS_HOME)/examples/fibonacci; run-client
