#!/usr/bin/awk -f

#< AWK - Remove duplicate lines

!($0 in a){a[$0];print}