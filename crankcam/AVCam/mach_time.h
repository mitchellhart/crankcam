<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<!-- saved from url=(0079)http://www.opensource.apple.com/source/xnu/xnu-1456.1.26/osfmk/mach/mach_time.h -->
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en"><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<title>mach_time.h</title>
<style type="text/css">
.enscript-comment { font-style: italic; color: rgb(178,34,34); }
.enscript-function-name { font-weight: bold; color: rgb(0,0,255); }
.enscript-variable-name { font-weight: bold; color: rgb(184,134,11); }
.enscript-keyword { font-weight: bold; color: rgb(160,32,240); }
.enscript-reference { font-weight: bold; color: rgb(95,158,160); }
.enscript-string { font-weight: bold; color: rgb(188,143,143); }
.enscript-builtin { font-weight: bold; color: rgb(218,112,214); }
.enscript-type { font-weight: bold; color: rgb(34,139,34); }
.enscript-highlight { text-decoration: underline; color: 0; }
</style>
</head>
<body id="top">
<h1 style="margin:8px;" id="f1">mach_time.h&nbsp;&nbsp;&nbsp;<span style="font-weight: normal; font-size: 0.5em;">[<a href="http://www.opensource.apple.com/source/xnu/xnu-1456.1.26/osfmk/mach/mach_time.h?txt">plain text</a>]</span></h1>
<hr>
<div></div>
<pre><span class="enscript-comment">/*
 * Copyright (c) 2001-2005 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 * 
 * Please obtain a copy of the License at
 * <a href="http://www.opensource.apple.com/apsl/">http://www.opensource.apple.com/apsl/</a> and read it before using this file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */</span>

#<span class="enscript-reference">ifndef</span>	<span class="enscript-variable-name">_MACH_MACH_TIME_H_</span>
#<span class="enscript-reference">define</span>	<span class="enscript-variable-name">_MACH_MACH_TIME_H_</span>

#<span class="enscript-reference">include</span> <span class="enscript-string">&lt;mach/mach_types.h&gt;</span>

#<span class="enscript-reference">include</span> <span class="enscript-string">&lt;sys/cdefs.h&gt;</span>

<span class="enscript-type">struct</span> mach_timebase_info {
	uint32_t	numer;
	uint32_t	denom;
};

<span class="enscript-type">typedef</span> <span class="enscript-type">struct</span> mach_timebase_info	*mach_timebase_info_t;
<span class="enscript-type">typedef</span> <span class="enscript-type">struct</span> mach_timebase_info	mach_timebase_info_data_t;

__BEGIN_DECLS
#<span class="enscript-reference">ifndef</span>	<span class="enscript-variable-name">KERNEL</span>

kern_return_t		mach_timebase_info(
						mach_timebase_info_t	info);

kern_return_t		mach_wait_until(
						uint64_t		deadline);

#<span class="enscript-reference">endif</span>	<span class="enscript-comment">/* KERNEL */</span>

uint64_t			mach_absolute_time(<span class="enscript-type">void</span>);
__END_DECLS

#<span class="enscript-reference">endif</span> <span class="enscript-comment">/* _MACH_MACH_TIME_H_ */</span>
</pre>
<hr>
</body></html>