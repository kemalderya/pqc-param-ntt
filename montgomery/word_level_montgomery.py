#########################################################
# This block performs word-level montgomery multiplication
# It works with different NTT-length and modulus
def montgomery_wl(A,B,q,L,w,mu):
    # A,B: inputs (assuming they are in regular domain, A,B<q)
    # q  : modulus
    # L  : number of iterations               \
    # w  : word-size                          | -> Montgomery variables
    # mu : pre-computed constant -q^-1 mod R  /
    # where R is 2**(w*L)
    # Res: outputs (A*B*R^-1 mod q, Res<q)

    T1 = A*B

    qH = ((q-1) >> w)

    for i in range(L):
        T2H = T1 >> w
        T2L = T1 & (2**w - 1) # T2L = T1 % (2**w)
        T2  = T2L * (-1) # mu is always going to be -1 for NTT-friendly primes
        T2  = T2 & (2**w - 1)

        carry = ((T2 >> (w-1)) & 0x1) | ((T2L >> (w-1)) & 0x1)

        T1 = T2H + qH*T2 + carry

    T4 = T1 - q

    if (T4 < 0):
        Res = T1
    else:
        Res = T4

    return Res

#########################################################

#########################################################
# This block performs word-level montgomery multiplication with incomplete arithmetic
# It works with different NTT-length and modulus
def montgomery_wl_incomplete(A,B,q,L,w,mu):
    # A,B: inputs (assuming they are in regular domain, A,B<2**log(q))
    # q  : modulus
    # L  : number of iterations               \
    # w  : word-size                          | -> Montgomery variables
    # mu : pre-computed constant -q^-1 mod R  /
    # where R is 2**(w*L)
    # Res: outputs (A*B*R^-1 mod q, Res<2**log(q))
    """
    For incomplete montgomery to work:
    inputs and output < 2*q
    R = 2^(k+2) where k = log(q) ---> This is the case when doing regular Montgomery
    """

    T1 = A*B

    qH = ((q-1) >> w)

    for i in range(L):
        T2H = T1 >> w
        T2L = T1 & (2**w - 1) # T2L = T1 % (2**w)
        T2  = T2L * (-1) # mu is always going to be -1 for NTT-friendly primes
        T2  = T2 & (2**w - 1)

        carry = ((T2 >> (w-1)) & 0x1) | ((T2L >> (w-1)) & 0x1)

        T1 = T2H + qH*T2 + carry

    return T1

#########################################################
