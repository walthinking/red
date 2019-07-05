Red [
	Title:   "GPIO port scheme"
	Author:  "Nenad Rakocevic"
	File: 	 %GPIO.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

gpio-scheme: context [

	#system [
		#import [
			LIBC-file cdecl [
				mmap: "mmap" [
					address		[byte-ptr!]
					size		[integer!]
					protection	[integer!]
					flags		[integer!]
					fd			[integer!]
					offset		[integer!]
					return:		[byte-ptr!]
				]
				munmap: "munmap" [
					address		[byte-ptr!]
					size		[integer!]
					return:		[integer!]
				]
			]
		]

		#define GPIO_PERIPH_RPI23	3F000000h		;-- RPi 2 & 3 peripherals
		#define GPIO_PERIPH_RPI01	20000000h		;-- RPi zero & 1 peripherals
		#define GPIO_OFFSET			00200000h

		#enum gpio-pins! [
			GPFSEL0:   	00h
			GPFSEL1:   	04h
			GPFSEL2:   	08h
			GPFSEL3:   	0Ch
			GPFSEL4:   	10h
			GPFSEL5:   	14h
			GPSET0:    	1Ch
			GPSET1:    	20h
			GPCLR0:    	28h
			GPCLR1:    	2Ch
			GPLEV0:    	34h
			GPLEV1:    	38h
			GPEDS0:    	40h
			GPEDS1:    	44h
			GPREN0:    	4Ch
			GPREN1:    	50h
			GPFEN0:    	58h
			GPFEN1:    	5Ch
			GPHEN0:    	64h
			GPHEN1:    	68h
			GPLEN0:    	70h
			GPLEN1:    	74h
			GPAREN0:   	7Ch
			GPAREN1:   	80h
			GPAFEN0:   	88h
			GPAFEN1:   	8Ch
			GPPUD:     	94h
			GPPUDCLK0: 	98h
			GPPUDCLK1: 	9Ch
		]

		pause: func [time [integer!]][platform/usleep time * 1000]

		select: func [
			base [byte-ptr!]
			pin	 [integer!]
			mode [integer!]
			/local
				GPFSEL [int-ptr!]
				index  [integer!]
				shift  [integer!]
				mask   [integer!]
		][
			index: pin * CDh >> 11
			shift: pin - (index * 10) * 3
			GPFSEL: as int-ptr! (base + (index << 2))
			mask: GPFSEL/value and not (7 << shift)
			GPFSEL/value: mode << shift or mask
		]

		set: func [
			base [byte-ptr!]
			pin	  [integer!]
			high? [logic!]
			/local
				p	  [int-ptr!]
				index [integer!]
				bit	  [integer!]
				mode  [integer!]
		][
			index: pin >> 3
			bit: 1 << (pin and 31)

			mode: either high? [GPSET0][GPCLR0]
			p: as int-ptr! (base + mode + index)
			p/value: bit
		]
	]
	
	gpio.open: routine [
		state [block!]
		/local
			handle [red-handle!]
			fd	   [integer!]
			base   [byte-ptr!]
	][
		fd: platform/io-open "/dev/gpiomem" 00101002h	;-- O_RDWR or O_SYNC
		if fd > 0 [
			handle: as red-handle! block/rs-head state
			handle/header: TYPE_HANDLE
			handle/value: fd

			base: mmap null 4096 MMAP_PROT_RW MMAP_MAP_SHARED fd GPIO_PERIPH_RPI23 or GPIO_OFFSET
			if any [
				(as-integer base) > 0
				-1024 < as-integer base					;-- check if not in the error codes range
			][
				handle: handle + 1
				handle/header: TYPE_HANDLE
				handle/value: as-integer base
			]
		]
	]

	gpio.close: routine [
		state [block!]
		/local
			handle [red-handle!]
	][
		handle: as red-handle! (block/rs-head state) + 1
		if zero? munmap as byte-ptr! handle/value 4096 [handle/header: TYPE_NONE]
		handle: handle - 1
		if zero? platform/io-close handle/value [handle/header: TYPE_NONE]
	]

	;--- Port actions ---

	open: func [port /local state][
		state: port/state: copy [none none]				;-- fd (handle!), base (handle!)
		gpio.open port/state
		case [
			none? state/1 [cause-error 'access 'cannot-open ["failed to open /dev/gpiomem"]]
			none? state/2 [cause-error 'access 'cannot-open ["mmap() failed"]]
		]
	]

	close: func [port /local state][
		gpio.close state: port/state
		case [
			handle? state/1 [cause-error 'access 'cannot-close ["failed to close /dev/gpiomem"]]
			handle? state/2 [cause-error 'access 'cannot-close ["mmunap() failed"]]
		]
	]
]

register-scheme make system/standard/scheme [
	name: 'GPIO
	title: "GPIO access for Raspberry Pi boards"
	actor: gpio-scheme
]

p: open gpio://
probe p/state
close p
