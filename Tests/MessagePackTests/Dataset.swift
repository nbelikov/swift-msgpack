/*
This dataset is adopted from msgpack-test-suite written by Yusuke Kawasaki and
distributed under the terms of the MIT License.
Project URL: https://github.com/kawanet/msgpack-test-suite/


MIT License

Copyright (c) 2017-2018 Yusuke Kawasaki

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

import struct Foundation.Data

let nilDataset = Dataset<Int?>([
    // 10.nil.yaml:
    (nil, [
        "c0",
    ]),
])

let boolDataset = Dataset([
    // 11.bool.yaml:
    (false, [
        "c2",
    ]),

    (true, [
        "c3",
    ]),
])

// FIXME: Extend Data to conform to MessagePackCompatible
/*
let binaryDataset = Dataset([
    // 12.binary.yaml:
    (Data(), [ // [] - empty
        "c4-00",
        "c5-00-00",
        "c6-00-00-00-00",
    ]),

    (Data([0x01]), [ // [1]
        "c4-01-01",
        "c5-00-01-01",
        "c6-00-00-00-01-01",
    ]),

    (Data([0x00, 0xff]), [ // [0, 255]
        "c4-02-00-ff",
        "c5-00-02-00-ff",
        "c6-00-00-00-02-00-ff",
    ]),
])
*/

// NOTE: float32 and float64 formats are commented out for positiveIntDataset
// and negativeIntDataset since this implementation doesn't allow implicit
// conversions between floating point and integral values.
// NOTE: The contents of 23.number-bignum.yaml are split and appended to
// positiveIntDataset and negativeIntDataset since the test runner would
// process 64-bit integer data exactly the same way as it would with 32-bit.
// NOTE: The test runner will assume that the 0-th element in packed values
// list is the most compact and therefore correct way to encode a value.  Since
// this implementation prefers packing to signed integers unless an unsinged
// integer would be more compact, appropriate values are moved to top.

let positiveIntDataset = Dataset<UInt64>([
    // 20.number-positive.yaml:
    (0, [ // 0x0000
        "00",                          // 0 ... 127
        "cc-00",                       // unsigned int8
        "cd-00-00",                    // unsigned int16
        "ce-00-00-00-00",              // unsigned int32
        "cf-00-00-00-00-00-00-00-00",  // unsigned int64
        "d0-00",                       // signed int8
        "d1-00-00",                    // signed int16
        "d2-00-00-00-00",              // signed int32
        "d3-00-00-00-00-00-00-00-00",  // signed int64
        // "ca-00-00-00-00",              // float
        // "cb-00-00-00-00-00-00-00-00",  // double
    ]),

    (1, [ // 0x0001
        "01",
        "cc-01",
        "cd-00-01",
        "ce-00-00-00-01",
        "cf-00-00-00-00-00-00-00-01",
        "d0-01",
        "d1-00-01",
        "d2-00-00-00-01",
        "d3-00-00-00-00-00-00-00-01",
        // "ca-3f-80-00-00",
        // "cb-3f-f0-00-00-00-00-00-00",
    ]),

    (127, [ // 0x007F
        "7f",
        "cc-7f",
        "cd-00-7f",
        "ce-00-00-00-7f",
        "cf-00-00-00-00-00-00-00-7f",
        "d0-7f",
        "d1-00-7f",
        "d2-00-00-00-7f",
        "d3-00-00-00-00-00-00-00-7f",
    ]),

    (128, [ // 0x0080
        "cc-80",
        "cd-00-80",
        "ce-00-00-00-80",
        "cf-00-00-00-00-00-00-00-80",
        "d1-00-80",
        "d2-00-00-00-80",
        "d3-00-00-00-00-00-00-00-80",
    ]),

    (255, [ // 0x00FF
        "cc-ff",
        "cd-00-ff",
        "ce-00-00-00-ff",
        "cf-00-00-00-00-00-00-00-ff",
        "d1-00-ff",
        "d2-00-00-00-ff",
        "d3-00-00-00-00-00-00-00-ff",
    ]),

    (256, [ // 0x0100
        "d1-01-00",
        "cd-01-00",
        "ce-00-00-01-00",
        "cf-00-00-00-00-00-00-01-00",
        "d2-00-00-01-00",
        "d3-00-00-00-00-00-00-01-00",
    ]),

    (65535, [ // 0xFFFF
        "cd-ff-ff",
        "ce-00-00-ff-ff",
        "cf-00-00-00-00-00-00-ff-ff",
        "d2-00-00-ff-ff",
        "d3-00-00-00-00-00-00-ff-ff",
    ]),

    (65536, [ // 0x000100000
        "d2-00-01-00-00",
        "ce-00-01-00-00",
        "cf-00-00-00-00-00-01-00-00",
        "d3-00-00-00-00-00-01-00-00",
    ]),

    (2147483647, [ // 0x7FFFFFFF
        "d2-7f-ff-ff-ff",
        "ce-7f-ff-ff-ff",
        "cf-00-00-00-00-7f-ff-ff-ff",
        "d3-00-00-00-00-7f-ff-ff-ff",
    ]),

    (2147483648, [ // 0x80000000
        "ce-80-00-00-00",              // unsigned int32
        "cf-00-00-00-00-80-00-00-00",  // unsigned int64
        "d3-00-00-00-00-80-00-00-00",  // signed int64
        // "ca-4f-00-00-00",              // float
        // "cb-41-e0-00-00-00-00-00-00",  // double
    ]),

    (4294967295, [ // 0xFFFFFFFF
        "ce-ff-ff-ff-ff",
        "cf-00-00-00-00-ff-ff-ff-ff",
        "d3-00-00-00-00-ff-ff-ff-ff",
        // "cb-41-ef-ff-ff-ff-e0-00-00",
    ]),

    // 23.number-bignum.yaml:
    (4294967296, [ // +0x0000000100000000
        "d3-00-00-00-01-00-00-00-00",  // signed int64
        "cf-00-00-00-01-00-00-00-00",  // unsigned int64
        // "ca-4f-80-00-00",              // float
        // "cb-41-f0-00-00-00-00-00-00",  // double
    ]),

    (281474976710656, [ // +0x0001000000000000
        "d3-00-01-00-00-00-00-00-00",  // signed int64
        "cf-00-01-00-00-00-00-00-00",  // unsigned int64
        // "ca-57-80-00-00",              // float
        // "cb-42-f0-00-00-00-00-00-00",  // double
    ]),

    (9223372036854775807, [ // +0x7FFFFFFFFFFFFFFF
        "d3-7f-ff-ff-ff-ff-ff-ff-ff",  // signed int64
        "cf-7f-ff-ff-ff-ff-ff-ff-ff",  // unsigned int64
    ]),

    (9223372036854775808, [ // +0x8000000000000000
        "cf-80-00-00-00-00-00-00-00",  // unsigned int64
    ]),

    (18446744073709551615, [ // +0xFFFFFFFFFFFFFFFF
        "cf-ff-ff-ff-ff-ff-ff-ff-ff",  // unsigned int64
    ]),
])

let negativeIntDataset = Dataset<Int64>([
    // 21.number-negative.yaml:
    (-1, [ // 0xFFFFFFFF
        "ff",                          // -1 ... -32
        "d0-ff",                       // signed int8
        "d1-ff-ff",                    // signed int16
        "d2-ff-ff-ff-ff",              // signed int32
        "d3-ff-ff-ff-ff-ff-ff-ff-ff",  // signed int64
        // "ca-bf-80-00-00",              // float
        // "cb-bf-f0-00-00-00-00-00-00",  // double
    ]),

    (-32, [ // 0xFFFFFFE0
        "e0",
        "d0-e0",
        "d1-ff-e0",
        "d2-ff-ff-ff-e0",
        "d3-ff-ff-ff-ff-ff-ff-ff-e0",
        // "ca-c2-00-00-00",
        // "cb-c0-40-00-00-00-00-00-00",
    ]),

    (-33, [ // 0xFFFFFFDF
        "d0-df",
        "d1-ff-df",
        "d2-ff-ff-ff-df",
        "d3-ff-ff-ff-ff-ff-ff-ff-df",
    ]),

    (-128, [ // 0xFFFFFF80
        "d0-80",
        "d1-ff-80",
        "d2-ff-ff-ff-80",
        "d3-ff-ff-ff-ff-ff-ff-ff-80",
    ]),

    (-256, [ // 0xFFFFFF00
        "d1-ff-00",
        "d2-ff-ff-ff-00",
        "d3-ff-ff-ff-ff-ff-ff-ff-00",
    ]),

    (-32768, [ // 0xFFFF8000
        "d1-80-00",
        "d2-ff-ff-80-00",
        "d3-ff-ff-ff-ff-ff-ff-80-00",
    ]),

    (-65536, [ // 0xFFFF0000
        "d2-ff-ff-00-00",
        "d3-ff-ff-ff-ff-ff-ff-00-00",
    ]),

    (-2147483648, [ // 0x80000000
        "d2-80-00-00-00",
        "d3-ff-ff-ff-ff-80-00-00-00",
        // "cb-c1-e0-00-00-00-00-00-00",
    ]),

    // 23.number-bignum.yaml:
    (-4294967296, [ // -0x0000000100000000
        "d3-ff-ff-ff-ff-00-00-00-00",  // signed int64
        // "cb-c1-f0-00-00-00-00-00-00",  // double
    ]),

    (-281474976710656, [ // -0x0001000000000000
        "d3-ff-ff-00-00-00-00-00-00",  // signed int64
        // "ca-d7-80-00-00",              // float
        // "cb-c2-f0-00-00-00-00-00-00",  // double
    ]),

    (-9223372036854775807, [ // -0x7FFFFFFFFFFFFFFF
        "d3-80-00-00-00-00-00-00-01",  // signed int64
    ]),

    (-9223372036854775808, [ // -0x8000000000000000
        "d3-80-00-00-00-00-00-00-00",  // signed int64
    ]),
])

let floatDataset = Dataset<Float>([
    // 22.number-float.yaml:
    (0.5, [
        "ca-3f-00-00-00",
        "cb-3f-e0-00-00-00-00-00-00",
    ]),

    (-0.5, [
        "ca-bf-00-00-00",
        "cb-bf-e0-00-00-00-00-00-00",
    ]),
])

// NOTE: The contents of 30.string-ascii.yaml, 31.string-utf8.yaml and
// 32.string-emoji.yaml are combined into a single dataset.

let stringDataset = Dataset([
    // 30.string-ascii.yaml:
    ("", [ // empty string
        "a0",
        "d9-00",
        "da-00-00",
        "db-00-00-00-00",
    ]),

    ("a", [
        "a1-61",
        "d9-01-61",
        "da-00-01-61",
        "db-00-00-00-01-61",
    ]),

    ("1234567890123456789012345678901", [
        "bf-31-32-33-34-35-36-37-38-39-30-31-32-33-34-35-36-37-38-39-30-31-" +
        "32-33-34-35-36-37-38-39-30-31",
        "d9-1f-31-32-33-34-35-36-37-38-39-30-31-32-33-34-35-36-37-38-39-30-" +
        "31-32-33-34-35-36-37-38-39-30-31",
        "da-00-1f-31-32-33-34-35-36-37-38-39-30-31-32-33-34-35-36-37-38-39-" +
        "30-31-32-33-34-35-36-37-38-39-30-31",
    ]),

    ("12345678901234567890123456789012", [
        "d9-20-31-32-33-34-35-36-37-38-39-30-31-32-33-34-35-36-37-38-39-30-" +
        "31-32-33-34-35-36-37-38-39-30-31-32",
        "da-00-20-31-32-33-34-35-36-37-38-39-30-31-32-33-34-35-36-37-38-39-" +
        "30-31-32-33-34-35-36-37-38-39-30-31-32",
    ]),

    // 31.string-utf8.yaml:
    ("Кириллица", [ // Russian Cyrillic alphabet
        "b2-d0-9a-d0-b8-d1-80-d0-b8-d0-bb-d0-bb-d0-b8-d1-86-d0-b0",
        "d9-12-d0-9a-d0-b8-d1-80-d0-b8-d0-bb-d0-bb-d0-b8-d1-86-d0-b0",
    ]),

    ("ひらがな", [ // Japanese Hiragana character
        "ac-e3-81-b2-e3-82-89-e3-81-8c-e3-81-aa",
        "d9-0c-e3-81-b2-e3-82-89-e3-81-8c-e3-81-aa",
    ]),

    ("한글", [ // Korean Hangul character
        "a6-ed-95-9c-ea-b8-80",
        "d9-06-ed-95-9c-ea-b8-80",
    ]),

    ("汉字", [ // Simplified Chinese character
        "a6-e6-b1-89-e5-ad-97",
        "d9-06-e6-b1-89-e5-ad-97",
    ]),

    ("漢字", [ // Traditional Chinese character
        "a6-e6-bc-a2-e5-ad-97",
        "d9-06-e6-bc-a2-e5-ad-97",
    ]),

    // 32.string-emoji.yaml:
    ("❤", [ // U+2764 HEAVY BLACK HEART
        "a3-e2-9d-a4",
        "d9-03-e2-9d-a4",
    ]),

    ("🍺", [ // U+1F37A BEER MUG
        "a4-f0-9f-8d-ba",
        "d9-04-f0-9f-8d-ba",
    ]),
])

/*

# 40.array.yaml:

# array

# [] // empty
- array: []
  msgpack:
    - "90"
    - "dc-00-00"
    - "dd-00-00-00-00"

# [1]
- array: [1]
  msgpack:
    - "91-01"
    - "dc-00-01-01"
    - "dd-00-00-00-01-01"

# [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
- array: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
  msgpack:
    - "9f-01-02-03-04-05-06-07-08-09-0a-0b-0c-0d-0e-0f"
    - "dc-00-0f-01-02-03-04-05-06-07-08-09-0a-0b-0c-0d-0e-0f"
    - "dd-00-00-00-0f-01-02-03-04-05-06-07-08-09-0a-0b-0c-0d-0e-0f"

# [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
- array: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
  msgpack:
    - "dc-00-10-01-02-03-04-05-06-07-08-09-0a-0b-0c-0d-0e-0f-10"
    - "dd-00-00-00-10-01-02-03-04-05-06-07-08-09-0a-0b-0c-0d-0e-0f-10"

# ['a']
- array: ["a"]
  msgpack:
    - "91-a1-61"
    - "dc-00-01-a1-61"
    - "dd-00-00-00-01-a1-61"

# 41.map.yaml:

# map

# {} // empty
- map: {}
  msgpack:
    - "80"
    - "de-00-00"
    - "df-00-00-00-00"

# {a: 1}
- map: {"a": 1}
  msgpack:
    - "81-a1-61-01"
    - "de-00-01-a1-61-01"
    - "df-00-00-00-01-a1-61-01"

# {a: 'A'}
- map: {"a": "A"}
  msgpack:
    - "81-a1-61-a1-41"
    - "de-00-01-a1-61-a1-41"
    - "df-00-00-00-01-a1-61-a1-41"

# 42.nested.yaml:

# nested

# array of array
- array: [[]]
  msgpack:
    - "91-90"
    - "dc-00-01-dc-00-00"
    - "dd-00-00-00-01-dd-00-00-00-00"

# array of map
- array: [{}]
  msgpack:
    - "91-80"
    - "dc-00-01-80"
    - "dd-00-00-00-01-80"

# map of map
- map: {"a": {}}
  msgpack:
    - "81-a1-61-80"
    - "de-00-01-a1-61-de-00-00"
    - "df-00-00-00-01-a1-61-df-00-00-00-00"

# map of array
- map: {"a": []}
  msgpack:
    - "81-a1-61-90"
    - "de-00-01-a1-61-90"
    - "df-00-00-00-01-a1-61-90"

# 50.timestamp.yaml:

# timestamp
#
# nanoseconds between 0000-00-00 and 9999-12-31

# 2018-01-02T03:04:05.000000000Z
- timestamp: [1514862245, 0]
  msgpack:
    - "d6-ff-5a-4a-f6-a5"

# 2018-01-02T03:04:05.678901234Z
- timestamp: [1514862245, 678901234]
  msgpack:
    - "d7-ff-a1-dc-d7-c8-5a-4a-f6-a5"

# 2038-01-19T03:14:07.999999999Z
- timestamp: [2147483647, 999999999]
  msgpack:
    - "d7-ff-ee-6b-27-fc-7f-ff-ff-ff"

# 2038-01-19T03:14:08.000000000Z
- timestamp: [2147483648, 0]
  msgpack:
    - "d6-ff-80-00-00-00"

# 2038-01-19T03:14:08.000000001Z
- timestamp: [2147483648, 1]
  msgpack:
    - "d7-ff-00-00-00-04-80-00-00-00"

# 2106-02-07T06:28:15.000000000Z
- timestamp: [4294967295, 0]
  msgpack:
    - "d6-ff-ff-ff-ff-ff"

# 2106-02-07T06:28:15.999999999Z
- timestamp: [4294967295, 999999999]
  msgpack:
    - "d7-ff-ee-6b-27-fc-ff-ff-ff-ff"

# 2106-02-07T06:28:16.000000000Z
- timestamp: [4294967296, 0]
  msgpack:
    - "d7-ff-00-00-00-01-00-00-00-00"

# 2514-05-30T01:53:03.999999999Z
- timestamp: [17179869183, 999999999]
  msgpack:
    - "d7-ff-ee-6b-27-ff-ff-ff-ff-ff"

# 2514-05-30T01:53:04.000000000Z
- timestamp: [17179869184, 0]
  msgpack:
    - "c7-0c-ff-00-00-00-00-00-00-00-04-00-00-00-00"

# 1969-12-31T23:59:59.000000000Z
- timestamp: [-1, 0]
  msgpack:
    - "c7-0c-ff-00-00-00-00-ff-ff-ff-ff-ff-ff-ff-ff"

# 1969-12-31T23:59:59.999999999Z
- timestamp: [-1, 999999999]
  msgpack:
    - "c7-0c-ff-3b-9a-c9-ff-ff-ff-ff-ff-ff-ff-ff-ff"

# 1970-01-01T00:00:00.000000000Z
- timestamp: [0, 0]
  msgpack:
    - "d6-ff-00-00-00-00"

# 1970-01-01T00:00:00.000000001Z
- timestamp: [0, 1]
  msgpack:
    - "d7-ff-00-00-00-04-00-00-00-00"

# 1970-01-01T00:00:01.000000000Z
- timestamp: [1, 0]
  msgpack:
    - "d6-ff-00-00-00-01"

# 1899-12-31T23:59:59.999999999Z
- timestamp: [-2208988801, 999999999]
  msgpack:
    - "c7-0c-ff-3b-9a-c9-ff-ff-ff-ff-ff-7c-55-81-7f"

# 1900-01-01T00:00:00.000000000Z
- timestamp: [-2208988800, 0]
  msgpack:
    - "c7-0c-ff-00-00-00-00-ff-ff-ff-ff-7c-55-81-80"

# 0000-01-01T00:00:00.000000000Z
- timestamp: [-62167219200, 0]
  msgpack:
    - "c7-0c-ff-00-00-00-00-ff-ff-ff-f1-86-8b-84-00"

# 9999-12-31T23:59:59.999999999Z
- timestamp: [253402300799, 999999999]
  msgpack:
    - "c7-0c-ff-3b-9a-c9-ff-00-00-00-3a-ff-f4-41-7f"

# 60.ext.yaml:

# ext

# fixext 1
- ext: [1, "10"]
  msgpack:
    - "d4-01-10"

# fixext 2
- ext: [2, "20-21"]
  msgpack:
    - "d5-02-20-21"

# fixext 4
- ext: [3, "30-31-32-33"]
  msgpack:
    - "d6-03-30-31-32-33"

# fixext 8
- ext: [4, "40-41-42-43-44-45-46-47"]
  msgpack:
    - "d7-04-40-41-42-43-44-45-46-47"

# fixext 16
- ext: [5, "50-51-52-53-54-55-56-57-58-59-5a-5b-5c-5d-5e-5f"]
  msgpack:
    - "d8-05-50-51-52-53-54-55-56-57-58-59-5a-5b-5c-5d-5e-5f"

# ext size=0
- ext: [6, ""]
  msgpack:
    - "c7-00-06"            # ext 8
    - "c8-00-00-06"         # ext 16
    - "c9-00-00-00-00-06"   # ext 32

# ext size=3
- ext: [7, "70-71-72"]
  msgpack:
    - "c7-03-07-70-71-72"           # ext 8
    - "c8-00-03-07-70-71-72"        # ext 16
    - "c9-00-00-00-03-07-70-71-72"  # ext 32

*/
