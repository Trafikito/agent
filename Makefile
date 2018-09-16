# make file to install scripts 

all: environment directories scripts

directories:
	 @test -d $(TRAFIKITO_INSTALL_DIR)        || mkdir $(TRAFIKITO_INSTALL_DIR)
	 @test -d $(TRAFIKITO_INSTALL_DIR)/lib    || mkdir $(TRAFIKITO_INSTALL_DIR)/lib
	 @test -d $(TRAFIKITO_INSTALL_DIR)/system || mkdir $(TRAFIKITO_INSTALL_DIR)/system

scripts: $(TRAFIKITO_INSTALL_DIR)/trafikito_install.sh\
         $(TRAFIKITO_INSTALL_DIR)/trafikito\
         $(TRAFIKITO_INSTALL_DIR)/uninstall.sh\
         $(TRAFIKITO_INSTALL_DIR)/LICENSE\
         $(TRAFIKITO_INSTALL_DIR)/README.md\
         $(TRAFIKITO_INSTALL_DIR)/lib/set_os.sh\
         $(TRAFIKITO_INSTALL_DIR)/lib/trafikito_agent.sh\
         $(TRAFIKITO_INSTALL_DIR)/lib/trafikito_wrapper.sh

$(TRAFIKITO_INSTALL_DIR)/trafikito_install.sh: trafikito_install.sh
	 cp $< $@ 

$(TRAFIKITO_INSTALL_DIR)/trafikito: trafikito
	 cp $< $@ 

$(TRAFIKITO_INSTALL_DIR)/uninstall.sh: uninstall.sh
	 cp $< $@ 

$(TRAFIKITO_INSTALL_DIR)/LICENSE: LICENSE
	 cp $< $@ 

$(TRAFIKITO_INSTALL_DIR)/README.md: README.md
	 cp $< $@ 

$(TRAFIKITO_INSTALL_DIR)/lib/set_os.sh: lib/set_os.sh
	 cp $< $@ 

$(TRAFIKITO_INSTALL_DIR)/lib/trafikito_agent.sh: lib/trafikito_agent.sh
	 cp $< $@ 

$(TRAFIKITO_INSTALL_DIR)/lib/trafikito_wrapper.sh: lib/trafikito_wrapper.sh
	 cp $< $@ 

environment:
ifndef TRAFIKITO_INSTALL_DIR
	$(error Environment variable TRAFIKITO_INSTALL_DIR not defined)
endif

allx:
	cp trafikito_agent_install.sh trafikito uninstall.sh $(HTMLDIR)
	cp lib/* $(HTMLDIR)/lib

run:
	sudo cp trafikito-install.sh trafikito uninstall.sh $(RUNDIR)
	sudo cp lib/* $(RUNDIR)/lib
