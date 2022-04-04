# Copyright 2020-2022 F4PGA Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

TESTS = pll
include $(shell pwd)/../../Makefile_test.common

json_test = python compare_output_json.py --json $(1)/$(1).json --golden $(1)/$(1).golden.json

define json_update =
$(1)_update_json:
	python compare_output_json.py --json $(1)/$(1).json --golden $(1)/$(1).golden.json --update
endef

pll_verify = $(call json_test,pll) && test $$(grep "PASS" pll/pll.txt | wc -l) -eq 2

