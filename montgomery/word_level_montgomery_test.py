import generate_prime as Prime
import word_level_montgomery as Mont
import util as Util

import math
import random
import sys

# ntt_type:
# if 0 --> satisfies condition q = 1 (mod n)
# if 1 --> satisfies condition q = 1 (mod 2n)

# K: bit-length of modulus
# N: ring size
# q: modulus

custom_word = 0

generate_test = 0

incomplete_arithmetic = 1

ntt_type = 1

K = 16
N = 256

while(1):
    if ntt_type == 0:
        q = Prime.generate_large_prime(K)
        if(q%N == 1):
            break
    else: # ntt_type == 1
        q = Prime.generate_large_prime(K)
        if(q%(2*N) == 1):
            break

K = len(bin(q)[2:])

# Parameter
print("--- *** ---")
print("n     ={}".format(N))
print("log(q)={}".format(K))
print("q     ={}".format(q))

# Montgomery constants
# w: word size
# L: iteration count (ceil(K/w))
# R: 2**(w*L)
# mu: -q^-1 mod R

if ntt_type == 0:
    w = int(math.log(N,2))
else:
    w = int(math.log(N,2))+1

if incomplete_arithmetic == 0:
    L = int(math.ceil((1.0*K)/(1.0*w)))
else:
    L = int(math.ceil((1.0*(K+2))/(1.0*w)))

R = 2**(w*L)
Rp= Util.modinv(R,q)
mu= R - Util.modinv(q,R)

print("--- *** ---")
print("q = 1 (mod {}n)".format(ntt_type+1))
print("incomp={}".format(incomplete_arithmetic))
print("w     ={}".format(w))
print("L     ={}".format(L))
print("w*L   ={}".format(w*L))
if incomplete_arithmetic:
    print("{} < log(q) <= {}".format(w*(L-1),w*L-2))
else:
    print("{} < log(q) <= {}".format(w*(L-1),w*L))

# Test

inc_limit = 2*q-1
# inc_limit = 2**K-1

# test_num = 1000000
test_num = 100000

if incomplete_arithmetic == 0:
    if generate_test:
        print("// log(q)={}, n={}, q=1 (mod {}*n)".format(K,N,ntt_type+1))

    for i in range(test_num):
        # Exact calculation
        A = random.randint(0,q-1)
        B = random.randint(0,q-1)

        C_check = (A*B*Rp) % q

        C = Mont.montgomery_wl(A,B,q,L,w,mu)

        # Check result
        if C_check == C:
            # print "Exact Calc - Dogru"
            pass
        else:
            print "Exact Calc...FAIL"
            sys.exit()

        if generate_test:
            # Print input
            print("A={}; B={}; q={}; s={}; i={}; #10; // res={}".format(A,B,q,11-w,L-1,C))

else:
    for i in range(test_num):
        # Incomplete calculation
        A = random.randint(0,inc_limit)
        B = random.randint(0,inc_limit)

        C_check = (A*B*Rp) % q

        C = Mont.montgomery_wl_incomplete(A,B,q,L,w,mu)

        # Check result
        if (C_check == (C%q)) and (C < inc_limit) and (0 <= C):
            # print "Incomplete Calc - Dogru"
            pass
        else:
            print "incomplete Calc...FAIL"
            print "A={}, B={}, C={}, C_check={}, limit={}".format(A,B,C,C_check,inc_limit)
            sys.exit()

print("--- *** ---")
print("Test...OK")
print("--- *** ---")
"""
# Bu Montgomery parametreleri ile beraber bu sistem:
# w: 8
# K: 16
# L: 2
# 8 < K <= 16 araligindaki tum prime'larda calisiyor.
# Orneklere bakalim

# Asagidaki ornekler icin calisiyor.
K_new = 9
# K_new = 10
# K_new = 11
# K_new = 12
# K_new = 13
# K_new = 14
# K_new = 15
# K_new = 16

# Asagidaki ornekler icin calismaz
# K_new = 8
# K_new = 17
# K_new = 18
# K_new = 19

while(1):
    if ntt_type == 0:
        q_new = Prime.generate_large_prime(K_new)
        if(q_new%N == 1):
            break
    else: # ntt_type == 1
        q_new = Prime.generate_large_prime(K_new)
        if(q_new%(2*N) == 1):
            break

Rp= Util.modinv(R,q_new)
mu= R - Util.modinv(q_new,R)

A = random.randint(0,q_new-1)
B = random.randint(0,q_new-1)

C_check = (A*B*Rp) % q_new

C = Mont.montgomery_wl(A,B,q_new,L,w,mu)

# Check result
if C_check == C:
    print "Dogru"
else:
    print "Yanlis"
"""
