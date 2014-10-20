default:
	./environment-to-dot live mattress > var/livemodav.dot
	cd var && $(MAKE) -f $(PWD)/Makefile-for-dot
