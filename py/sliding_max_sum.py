import sys

arr= [1, 4, 2, 10, 23, 3, 1, 0, 20]
k = 4

count = 0
max_int = -(sys.maxsize)

sum_k = 0

first_ix = 0

ix = 0

while ix < len(arr):
    if count < k:
        count += 1
        sum_k += arr[ix]
        ix += 1
        continue

    if sum_k > max_int:
        max_int = sum_k

    sum_k -= arr[first_ix]
    sum_k += arr[ix]
    first_ix += 1
    ix += 1

if max_int < sum_k:
    max_int = sum_k

print("Max sum of {} elements is {}".format(k, max_int))


