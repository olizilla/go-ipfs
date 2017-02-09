#!/bin/sh
#
# Copyright (c) 2016 Jeromy Johnson
# MIT Licensed; see the LICENSE file in this repository.
#

test_description="Test dag command"

. lib/test-lib.sh

test_init_ipfs

test_expect_success "make a few test files" '
	echo "foo" > file1 &&
	echo "bar" > file2 &&
	echo "baz" > file3 &&
	echo "qux" > file4 &&
	HASH1=$(ipfs add --pin=false -q file1) &&
	HASH2=$(ipfs add --pin=false -q file2) &&
	HASH3=$(ipfs add --pin=false -q file3) &&
	HASH4=$(ipfs add --pin=false -q file4)
'

test_expect_success "make an ipld object in json" '
	printf "{\"hello\":\"world\",\"cats\":[{\"/\":\"%s\"},{\"water\":{\"/\":\"%s\"}}],\"magic\":{\"/\":\"%s\"}}" $HASH1 $HASH2 $HASH3 > ipld_object
'

test_dag_cmd() {
	test_expect_success "can add an ipld object" '
		IPLDHASH=$(cat ipld_object | ipfs dag put)
	'

	test_expect_success "output looks correct" '
		EXPHASH="zdpuAzn7KZcQmKJvpEM1DgHXaybVj7mRP4ZMrkW94taYEuZHp"
		test $EXPHASH = $IPLDHASH
	'

	test_expect_success "various path traversals work" '
		ipfs cat $IPLDHASH/cats/0 > out1 &&
		ipfs cat $IPLDHASH/cats/1/water > out2 &&
		ipfs cat $IPLDHASH/magic > out3
	'

	test_expect_success "outputs look correct" '
		test_cmp file1 out1 &&
		test_cmp file2 out2 &&
		test_cmp file3 out3
	'

	test_expect_success "can pin cbor object" '
		ipfs pin add $EXPHASH
	'

	test_expect_success "after gc, objects still acessible" '
		ipfs repo gc > /dev/null &&
		ipfs refs -r --timeout=2s $EXPHASH > /dev/null
	'

	test_expect_success "can get object" '
		ipfs dag get $IPLDHASH > ipld_obj_out
	'

	test_expect_success "object links look right" '
		grep "{\"/\":\"" ipld_obj_out > /dev/null
	'

	test_expect_success "retreived object hashes back correctly" '
		IPLDHASH2=$(cat ipld_obj_out | ipfs dag put) &&
		test "$IPLDHASH" = "$IPLDHASH2"
	'

	test_expect_success "add a normal file" '
		HASH=$(echo "foobar" | ipfs add -q)
	'

	test_expect_success "can view protobuf object with dag get" '
		ipfs dag get $HASH > dag_get_pb_out
	'

	test_expect_success "output looks correct" '
		echo "{\"data\":\"CAISB2Zvb2JhcgoYBw==\",\"links\":[]}" > dag_get_pb_exp &&
		test_cmp dag_get_pb_exp dag_get_pb_out
	'

	test_expect_success "can call dag get with a path" '
		ipfs dag get $IPLDHASH/cats/0 > cat_out
	'

	test_expect_success "output looks correct" '
		echo "{\"data\":\"CAISBGZvbwoYBA==\",\"links\":[]}" > cat_exp &&
		test_cmp cat_exp cat_out
	'

	test_expect_success "non-canonical cbor input is normalized" '
	DATA="\xa2\x65\x61\x6c\x69\x6e\x6b\xd8\x2a\x58\x25\x00\x01\x71\x12\x20\x65\x96\x50\xfc\x34\x43\xc9\x16\x42\x80\x48\xef\xc5\xba\x45\x58\xdc\x86\x35\x94\x98\x0a\x59\xf5\xcb\x3c\x4d\x84\x86\x7e\x6d\x31\x63\x61\x72\x72\x80" 
	HASH=$(echo "$DATA" | ipfs dag put --format=cbor --input-enc=raw) &&
	test $HASH = "zdpuAyaAXrG12ax4EWuMxvFqBQuzwMGTW8C7NXAotCrcTnSXP" ||
	test_fsh echo $HASH
	'
}

# should work offline
test_dag_cmd

# should work online
test_launch_ipfs_daemon
test_dag_cmd
test_kill_ipfs_daemon

test_done