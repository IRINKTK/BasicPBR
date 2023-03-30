#ifndef MATH_EXTEND_INCLUDED
#define MATH_EXTEND_INCLUDED

/**
 * Computes x^5 using only multiply operations.
 *
 * @public-api
 */
half Pow5(half x) 
{
    half x2 = x * x;
    return x2 * x2 * x;
}

/**
 * Computes x^4 using only multiply operations.
 *
 * @public-api
 */
half Pow4(half x) 
{
    half x2 = x * x;
    return x2 * x2 * x;
}


/**
 * Computes x^2 as a single multiplication.
 *
 * @public-api
 */
half Pow2(half x) 
{
    return x * x;
}


// -------------------------------------
// Color
half CheapContrast(half In, half Contrast)
{
    half temp = lerp(0 - Contrast, 1 + Contrast, In);
    return clamp(temp, 0.0f, 1.0f);
}

#endif // MATH_EXTEND_INCLUDED