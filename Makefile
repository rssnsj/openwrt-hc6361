#
#
hiwifi_root = $(shell pwd)
openwrt_dir = openwrt-ar71xx
host_packages = build-essential git flex gettext libncurses5-dev unzip gawk liblzma-dev u-boot-tools
openwrt_feeds = libevent2 luci luci-app-samba xl2tpd pptpd pdnsd ethtool
### mwan3 luci-app-mwan3

HC6361: .install_feeds
	@cd $(openwrt_dir); \
		if [ -e .config ]; then \
			mv -vf .config .config.bak; \
			echo "WARNING: .config is updated, backed up as '.config.bak'"; \
		fi; \
		cp -vf ../config-hiwifi-hc6361 .config
	make -C $(openwrt_dir) V=s -j$(shell grep ^processor /proc/cpuinfo | wc -l)

recovery.bin: HC6361
	make -C recovery.bin

.install_feeds: .update_feeds
	@cd $(openwrt_dir); ./scripts/feeds install $(openwrt_feeds);
	@cd $(openwrt_dir)/package; \
	 [ -e rssnsj-feeds ] || git clone https://github.com/rssnsj/network-feeds.git rssnsj-feeds
	@touch .install_feeds

.update_feeds: .patched
	@cd $(openwrt_dir); ./scripts/feeds update;
	@touch .update_feeds

.patched: .checkout_svn
	@cd $(openwrt_dir); cat ../patches/*.patch | patch -p0
	@cp -vf config-hiwifi-hc6361 $(openwrt_dir)/.config
	@touch .patched

# 2. Checkout source code:
.checkout_svn: .check_hostdeps
#	svn co svn://svn.openwrt.org/openwrt/branches/barrier_breaker $(openwrt_dir) -r43770 || :
	@git clone https://github.com/rssnsj/lagacy-openwrt.git $(openwrt_dir) && \
	 cd $(openwrt_dir) && git reset --hard b763ba211deeab857ef7c2e5275e92c15dd5e249
	@[ -d /var/dl ] && ln -sf /var/dl $(openwrt_dir)/dl || :
	@touch .checkout_svn

.check_hostdeps:
# 1. Install required host components:
	@which dpkg >/dev/null 2>&1 || exit 0; \
	for p in $(host_packages); do \
		dpkg -s $$p >/dev/null 2>&1 || to_install="$$to_install$$p "; \
	done; \
	if [ -n "$$to_install" ]; then \
		echo "Please install missing packages by running the following commands:"; \
		echo "  sudo apt-get update"; \
		echo "  sudo apt-get install -y $$to_install"; \
		exit 1; \
	fi;
	@touch .check_hostdeps

menuconfig: .install_feeds
	@cd $(openwrt_dir); [ -f .config ] && mv -vf .config .config.bak || :
	@cp -vf config-hiwifi-hc6361 $(openwrt_dir)/.config
	@touch config-hiwifi-hc6361  # change modification time
	@make -C $(openwrt_dir) menuconfig
	@[ $(openwrt_dir)/.config -nt config-hiwifi-hc6361 ] && cp -vf $(openwrt_dir)/.config config-hiwifi-hc6361 || :

clean:
	make clean -C recovery.bin
	make clean -C $(openwrt_dir) V=s

