default:
	./environment-to-dot live mattress gandalf smaug barrister paulette mdj mami > var/livemodav.dot
	cd var && $(MAKE) -f $(PWD)/Makefile-for-dot
