.PHONY: build mkdrootfs clean
.ONESHELL:

KERNEL := linux-4.5.6.tar.xz
BUSYBOX := busybox-1.31.0.tar.bz2

TOP_DIR := $(shell pwd)
KERNEL_DIR := $(patsubst %.tar.xz,%, $(KERNEL))
BUSYBOX_DIR := $(patsubst %.tar.bz2,%, $(BUSYBOX))
ROOT_DIR := $(TOP_DIR)/rootfs

packages := $(KERNEL_DIR) $(BUSYBOX_DIR)


all: $(packages) build mkrootfs

$(KERNEL_DIR):
	cd $(TOP_DIR)
	wget https://mirrors.edge.kernel.org/pub/linux/kernel/v4.x/$(KERNEL)
	tar xvfJ $(KERNEL)
	cp config/linux.config $(KERNEL_DIR)/.config
	@cd $(KERNEL_DIR)
	patch -p1 < ../patches/linux-ilog2.diff
	perl -i -p -e 's/^CC[ \t]+=[ \t]*\$$\(CROSS_COMPILE\)gcc$$/CC\t\t= \$$\(CROSS_COMPILE\)gcc-7/' test.mk

$(BUSYBOX_DIR):
	cd $(TOP_DIR)
	wget https://busybox.net/downloads/$(BUSYBOX)
	tar xvfj $(BUSYBOX)
	cp config/busybox.config $(BUSYBOX_DIR)/.config
	@cd $(BUSYBOX_DIR)

build:
	make -C $(KERNEL_DIR) -j8
	make -C $(BUSYBOX_DIR) -j8 install

mkrootfs:
	cd $(TOP_DIR)
	@rm -rf $(ROOT_DIR)
	@mkdir -p $(ROOT_DIR)
	@cd $(ROOT_DIR)
	@cp ../$(BUSYBOX_DIR)/_install/* ./ -rf
	mkdir dev proc sys home etc
	cp -a /dev/{null,console,tty,tty1,tty2,tty3,tty4,ttyS0,ttyS1} dev/
	cat > init << INIT
	#!/bin/sh
	mount -t proc none /proc
	mount -t sysfs none /sys
	setsid cttyhack sh
	INIT

	cat > etc/inittab << INITTAB
	::respawn:/bin/cttyhack /bin/sh
	INITTAB

	chmod +x init
	find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../rootfs.cpio.gz

server:
	qemu-system-i386 -m 512 -kernel $(KERNEL_DIR)/arch/x86/boot/bzImage -initrd rootfs.cpio.gz -S -s -append "console=ttyS0" -serial stdio

clean:
	make -C $(KERNEL_DIR) clean
	make -C $(BUSYBOX_DIR) clean
	rm -rf $(ROOT_DIR)
	rm -f rootfs.cpio.gz

distclean:
	make clean
	rm -rf $(KERNEL) $(KERNEL_DIR) $(BUSYBOX) $(BUSYBOX_DIR) 

