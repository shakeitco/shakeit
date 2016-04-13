#!/usr/bin/env bats
#
# Unit tests for shake. To run these tests you must have bats
# installed. See https://github.com/sstephenson/bats

# shellcheck source=../shake.bash
source shake.bash "test_mode"
load test_helper

@test "index_of doesn't find match in empty array" {
  array=()
  run index_of "foo" "${array[@]}"
  assert_output -1
}

@test "index_of finds match in 1 item array" {
  array=("foo")
  run index_of "foo" "${array[@]}"
  assert_output 0
}

@test "index_of doesn't find match in 1 item array" {
  array=("abc")
  run index_of "foo" "${array[@]}"
  assert_output -1
}

@test "index_of finds match in 3 item array" {
  array=("abc" "foo" "def")
  run index_of "foo" "${array[@]}"
  assert_output 1
}

@test "index_of doesn't find match in 3 item array" {
  array=("abc" "def" "ghi")
  run index_of "foo" "${array[@]}"
  assert_output -1
}

@test "index_of finds match with multi argument syntax" {
  run index_of "foo" "abc" "def" "ghi" "foo"
  assert_output 3
}

@test "index_of returns index of first match" {
  run index_of foo abc foo def ghi foo
  assert_output 1
}
