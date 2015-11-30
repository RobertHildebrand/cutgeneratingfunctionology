# Make sure current directory is in path.  
# That's not true while doctesting (sage -t).
if '' not in sys.path:
    sys.path = [''] + sys.path

from igp import *

def transform_coho_interval(interval, shift, divisor):
    """Shift `interval` by `shift` and then divide it by `divisor`.

    EXAMPLES:
    sage: transform_coho_interval([1, 3], 1, 2)
    [1, 2]
    sage: transform_coho_interval([1, 3], 1, -1)
    [-4, -2]
    sage: transform_coho_interval(right_open_interval(-1,1), 1, 2)==right_open_interval(0, 1)
    True
    sage: transform_coho_interval(right_open_interval(-1,1), 1, -1)==left_open_interval(-2, 0)
    True
    """
    # This really wants to be in a compose method of FastPiecewise.
    x, y = (interval[0 ] + shift) / divisor, (interval[1 ] + shift) / divisor
    if divisor > 0:
        if len(interval) == 2:         # old-fashioned closed interval
            return [x, y]
        else:
            return closed_or_open_or_halfopen_interval(x, y, interval.left_closed, interval.right_closed)
    else:
        if len(interval) == 2:         # old-fashioned closed interval
            return [y, x]
        else:
            return closed_or_open_or_halfopen_interval(y, x, interval.right_closed, interval.left_closed)

def transform_piece(piece, shift, divisor):
    """Transform the `piece` = (interval, function) of a piecewise
    function by shifting `interval` by `shift` and then dividing it by
    `divisor`.
    """
    (interval, function) = piece
    try: 
        new_func = FastLinearFunction(function._slope * divisor, function._intercept - function._slope * shift)
    except AttributeError:
        x = var('x')
        g(x) = x * divisor - shift
        new_func = compose(function, g)
    return (transform_coho_interval(interval, shift, divisor), new_func)

def transform_piece_to_interval(piece, new_interval, old_interval=None):
    interval, function = piece
    if old_interval is None:
        old_interval = interval
    divisor = (old_interval[1] - old_interval[0]) / (new_interval[1] - new_interval[0])
    shift = new_interval[0] * divisor - old_interval[0]
    return transform_piece(piece, shift, divisor)

def multiplicative_homomorphism(function, multiplier):
    """
    Construct the function x -> function(multiplier * x). 

    `multiplier` must be a nonzero integer.

    EXAMPLES::

        sage: logging.disable(logging.INFO) # Suppress output in automatic tests.
        sage: h = multiplicative_homomorphism(gmic(f=4/5), 3)
        sage: extremality_test(h, False, f=4/15) # Provide f to suppress warning
        True
        sage: h = multiplicative_homomorphism(gmic(f=4/5), -2)
        sage: extremality_test(h, False, f=3/5)
        True
    """
    if not multiplier in ZZ or multiplier == 0:
        raise ValueError, "Bad parameter multiplier, needs to be a nonzero integer."
    elif multiplier > 0:
        i_range = range(multiplier)
    else: # multiplier < 0
        i_range = range(multiplier, 0)
    # This really wants to be in a compose method of FastLinear.
    new_pairs = [ transform_piece(piece, i, multiplier)
                  for piece in function.list() \
                  for i in i_range ]
    return FastPiecewise(new_pairs)

def automorphism(function, factor=-1):
    """Apply an automorphism.

    For the infinite group problem, apply the only nontrivial
    automorphism of the 1-dimensional infinite group problem to the
    given `function`, i.e., construct the function x -> function(-x).
    See Johnson (1974) for a discussion of the automorphisms.

    In the finite group case, factor must be an integer coprime with
    the group order.

    EXAMPLES::

        sage: logging.disable(logging.INFO) # Suppress output in automatic tests.
        sage: h = automorphism(gmic(f=4/5))
        sage: extremality_test(h, False, f=1/5)
        True
        sage: h = automorphism(restrict_to_finite_group(gmic(f=4/5)), 2)
        sage: extremality_test(h, False)
        True
    """
    if function.is_discrete():
        order = finite_group_order_from_function_f_oversampling_order(function, oversampling=None)
        if gcd(order, factor) != 1:
            raise ValueError, "factor must be coprime with the group order, %s" % order
        new_pairs = [ singleton_piece(fractional(x * factor), y)
                      for x, y in itertools.izip(function.end_points(), function.values_at_end_points()) ]
        return FastPiecewise(new_pairs)
    else:
        if abs(factor) != 1:
            raise ValueError, "factor must be +1 or -1 (the default) in the infinite group case."
        return multiplicative_homomorphism(function, -1)

def projected_sequential_merge(g, n=1):
    """
    construct the one-dimensional projected sequential merge inequality: h = g(with f = nr) @_n^1 gmic(f = r).

    The notation "@_n^1" is given in [39] p.305, def.12 & eq.25 :
        h(x) = (xi(x) + n * g(fractional((n + 1) * x - r * xi(x)))) / (n + 1), where xi = gmic(r)

    Parameters:
        g (real) a valid inequality;
        n (integer).

    Function is known to be extreme under the conditions: c.f. [39] p.309, Lemma 1
        (1) g is a facet-defining inequality, with f=nr ;
        (2) E(g) is unique up to scaling, c.f.[39] p.289, def.6 & def.7 ;
        (3) [g]_{nr} is nondecreasing, c.f.[39] p.290, def.8 (where m=1).

    Note:
        g = gj_forward_3_slope() does not satisfy condition(3), but

        g = multiplicative_homomorphism(gj_forward_3_slope(),-1) satisfies (3).

    Examples:
        [39]  p.311, fig.5 ::

            sage: logging.disable(logging.INFO)
            sage: g = multiplicative_homomorphism(gj_forward_3_slope(f=2/3, lambda_1=1/4, lambda_2=1/4), -1)
            sage: extremality_test(g, False)
            True
            sage: h = projected_sequential_merge(g, n=1)
            sage: extremality_test(h, False)
            True

    Reference:
        [39] SS Dey, JPP Richard, Relations between facets of low-and high-dimensional group problems,
             Mathematical programming 123 (2), 285-313.
    """
    f = find_f(g)
    r = f / n
    xi = gmic(r)
    ith = bisect_left(g.end_points(), f)
    l = len(g.intervals())
    multiplier = (1 + n - f) / (1 - r)
    new_pairs = [ transform_piece(piece, 0, n)
                  for piece in g.list()[0:ith]]
    i = r * multiplier - f
    new_pairs += [ transform_piece(piece, i, multiplier)
                   for piece in g.list()[ith:l] ]
    new_pairs += [ transform_piece(piece, j + 1/(1-r), multiplier) 
                   for piece in g.list()
                   for j in range(n) ]
    new_g = FastPiecewise(new_pairs)
    h = (1 / (n+1)) * xi + (1 / (n+1)) * new_g
    return h

def finite_group_order_from_function_f_oversampling_order(fn, f=None, oversampling=None, order=None):
    """
    Determine a finite group order to use, based on the given parameters.

    EXAMPLES::
    sage: logging.disable(logging.INFO)
    sage: finite_group_order_from_function_f_oversampling_order(gmic(f=4/5), order=17)
    17
    sage: finite_group_order_from_function_f_oversampling_order(gmic(f=4/5))
    5
    sage: finite_group_order_from_function_f_oversampling_order(gj_forward_3_slope())
    45
    sage: finite_group_order_from_function_f_oversampling_order(gmic(f=4/5), oversampling=3)
    15
    """
    if not order is None:
        return order
    if not order is None and not oversampling is None:
        raise ValueError, "Only one of the `order` and `oversampling` parameters may be provided."
    if f is None:
        f = find_f(fn, no_error_if_not_minimal_anyway=True)
    bkpt_f = fn.end_points()
    if not f is None:
        bkpt_f = [f] + bkpt_f
    is_rational_bkpt_f, bkpt_f = is_all_QQ(bkpt_f)
    if is_rational_bkpt_f:
        bkpt_f_denominator = [denominator(x) for x in bkpt_f]
        q = lcm(bkpt_f_denominator)
        if oversampling is None:
            logging.info("Rational breakpoints and f; using group generated by them, (1/%s)Z" % q)
            return q
        else:
            grid_nb = oversampling * q
            logging.info("Rational breakpoints and f; using group generated by them, refined by the provided oversampling factor %s, (1/%s)Z" % (oversampling, grid_nb))
            if oversampling >= 3 and fn.is_continuous_defined():
                # TODO: Detect and handle the case that fn already was a finite group problem
                logging.info("This is a continuous function; because oversampling factor is >= 3, the extremality test on the restricted function will be equivalent to the extremality test on the original function.")
            return grid_nb
    else:
        raise ValueError, "This is a function with irrational breakpoints or f, so no natural finite group order is available; need to provide an `order` parameter."

def restrict_to_finite_group(function, f=None, oversampling=None, order=None):
    """Restrict the given `function` to the cyclic group of given `order`.
    
    If `order` is not given, it defaults to the group generated by the
    breakpoints of `function` and `f` if these data are rational.
    However, if `oversampling` is given, it must be a positive
    integer; then the group generated by the breakpoints of `function`
    and `f` will be refined by that factor.

    If `f` is not provided, uses the one found by `find_f`.

    Assume in the following that `f` and all breakpoints of `function`
    lie in the cyclic group and that `function` is continuous.

    Then the restriction is valid if and only if `function` is valid.
    The restriction is minimal if and only if `function` is minimal.
    The restriction is extreme if `function` is extreme. 
    FIXME: Add reference.

    If, in addition `oversampling` >= 3, then the following holds:
    The restriction is extreme if and only if `function` is extreme.
    This is Theorem 1.5 in [IR2].

    This `oversampling` factor of 3 is best possible, as demonstrated
    by function `kzh_2q_example_1` from [KZh2015a].
    
    EXAMPLES::

        sage: logging.disable(logging.WARN)
        sage: g = gj_2_slope()
        sage: extremality_test(g)
        True
        sage: gf = restrict_to_finite_group(g)
        sage: minimality_test(gf)
        True
        sage: finite_dimensional_extremality_test(gf)
        True
        sage: h = drlm_not_extreme_1()
        sage: extremality_test(h)
        False
        sage: h7 = restrict_to_finite_group(h)
        sage: h7.end_points()
        [0, 1/7, 2/7, 3/7, 4/7, 5/7, 6/7, 1]
        sage: minimality_test(h7)
        True
        sage: finite_dimensional_extremality_test(h7)
        True
        sage: h21 = restrict_to_finite_group(h, oversampling=3)
        sage: minimality_test(h21)
        True
        sage: finite_dimensional_extremality_test(h21)
        False
        sage: h28 = restrict_to_finite_group(h, order=28)
        sage: minimality_test(h28)
        True
        sage: finite_dimensional_extremality_test(h28)
        False
        sage: h5 = restrict_to_finite_group(h, order=5)
        sage: minimality_test(h5)
        False

    Reference:
        [IR2] A. Basu, R. Hildebrand, and M. Koeppe, Equivariant perturbation in Gomory and Johnson's infinite group problem.
                I. The one-dimensional case, Mathematics of Operations Research (2014), doi:10. 1287/moor.2014.0660

        [KZh2015a] M. Koeppe and Y. Zhou, New computer-based search
        strategies for extreme functions of the Gomory--Johnson
        infinite group problem, 2015, e-print
        http://arxiv.org/abs/1506.00017 [math.OC].

    """
    order = finite_group_order_from_function_f_oversampling_order(function, f, oversampling, order)
    pieces = [ (singleton_interval(x/order), FastLinearFunction(0, function(x/order))) for x in range(order+1) ]
    return FastPiecewise(pieces)

def interpolate_to_infinite_group(function, merge=True):
    """Interpolate the given `function` to make it a function in the
    infinite group problem.  

    `function` may be a function of a finite (cyclic) group problem, 
    represented as a `FastPiecewise` with singleton intervals within [0,1] as its parts.

    (`function` is actually allowed, however, to be more general; it can be any `FastPiecewise`.)
    
    See `restrict_to_finite_group` for a discussion of the relation of
    the finite and infinite group problem.

    If `merge` is True (the default), adjacent pieces of equal slopes are merged into one.

    EXAMPLES::
    
    The same as restrict_to_finite_group(drlm_not_extreme_1())::

        sage: logging.disable(logging.WARN)
        sage: h7 = discrete_function_from_points_and_values([0/7, 1/7, 2/7, 3/7, 4/7, 5/7, 6/7, 7/7], [0/10, 4/10, 8/10, 5/10, 2/10, 6/10, 10/10, 0/10])
        sage: finite_dimensional_extremality_test(h7)
        True
        sage: h = interpolate_to_infinite_group(h7)
        sage: extremality_test(h)
        False
        sage: h21 = restrict_to_finite_group(h, oversampling=3)
        sage: finite_dimensional_extremality_test(h21)
        False
        sage: h28 = restrict_to_finite_group(h, oversampling=4)
        sage: finite_dimensional_extremality_test(h28)
        False
        sage: h14 = restrict_to_finite_group(h, oversampling=2) # for this example, even factor 2 works!
        sage: finite_dimensional_extremality_test(h14)
        False

    """
    # TODO: Allow `function` to be just a list of (x, y) pairs.
    last_x, last_y = None, None
    pieces = []
    # We are not using
    # `piecewise_function_from_breakpoints_and_values` to allow to
    # interpolate some partially interpolated functions.
    # FIXME: Actually implement that.
    for (interval, fn) in function.list():
        x = interval[0]
        y = fn(x)
        if last_x is not None and last_x < x:
            slope = (y - last_y) / (x - last_x)
            intercept = last_y - slope * last_x
            pieces.append(([last_x, x], FastLinearFunction(slope, intercept)))
        last_x = interval[1]
        last_y = fn(last_x)
    return FastPiecewise(pieces, merge=merge)

def two_slope_fill_in(function, order=None):
    """
    Extend the given `function` to make it a 2-slope function in the
    infinite group problem.

    `function` may be a function of a finite (cyclic) group problem,
    represented as a `FastPiecewise` with singleton intervals within [0,1] as its parts.

    (`function` is actually allowed, however, to be more general; it can be any `FastPiecewise`. When the given `function` is a function for the infinite group problem, its `restrict_to_finite_group` with order=`order` would be considered.)

    [Johnson (1974), section 7; see also Gomory--Johnson (1972, I, II)] If `function` is a subadditive valid function for the finite group problem, then its 2-slope fill-in is a subadditive valid function for the infinite group problem.

    EXAMPLES::

        sage: logging.disable(logging.WARN)
        sage: h_dis = discrete_function_from_points_and_values([0,1/5,2/5,3/5,4/5,1],[0,1/2,1,1/2,1/2,0])
        sage: subadditivity_test(h_dis)
        True
        sage: h_fill = two_slope_fill_in(h_dis)
        sage: subadditivity_test(h_fill)
        True
        sage: number_of_slopes(h_fill)
        2

        sage: gmic() == two_slope_fill_in(gmic())
        True
    """
    if not function.is_discrete():
        function = restrict_to_finite_group(function, order=order)
    ## Experimental.
    sp, sm = limiting_slopes(function)
    last_x, last_y = None, None
    pieces = []
    for (interval, fn) in function.list():
        x = interval[0]
        y = fn(x)
        if last_x is not None and last_x < x:
            mx = (x*sm - last_x*sp + last_y - y)/(sm - sp)
            my = (last_y*sm - (last_x*sm - x*sm + y)*sp)/(sm - sp)
            if last_x < mx:
                pieces.append(closed_piece((last_x, last_y), (mx, my)))
            if mx < x:
                pieces.append(closed_piece((mx, my), (x, y)))
        last_x = interval[1]
        last_y = fn(last_x)
    return FastPiecewise(pieces)

def generate_pi_pwl(function, epsilon, f=None, order=None):
    """
    Approximate `function` by a piesewise linear function `pi_pwl` whose breakpoints are all rationals, such that |function(x) - pi_pwl(x)| <= epsilon for x in (0, 1).

    Assume that `function' is piecewise linear, and `f` is a rational number.

    Output `pi_pwl` and the order `q`.

    EXAMPLE::
    
        sage: logging.disable(logging.WARN)
        sage: h = piecewise_function_from_breakpoints_and_values([0,1/5,2/5,3/5,4/5,1],[0,1/2,1,1/2,1/2,0])
        sage: q, pi_pwl = generate_pi_pwl(h, 1/3)
        sage: q
        5
        sage: h_irr = piecewise_function_from_breakpoints_and_values([0,1/5,2/5,3/5+1/10/sqrt(5),4/5-1/10/sqrt(5),1],[0,1/2,1,1/2-1/4/sqrt(5),1/2+1/4/sqrt(5),0])
        sage: q, pi_pwl_irr = generate_pi_pwl(h_irr, 1/3)
        sage: q
        5
        sage: pi_pwl_irr == h
        True
    """
    try:
        q = finite_group_order_from_function_f_oversampling_order(function, f=f, order=order)
    except:
        # has irrational breakpoints, do approximation.
        if not f:
            f = find_f(function)
        if not f in QQ:
            raise ValueError, "f is not a rational number."
        order = f.denominator()
        smax = max([abs(fn._slope) for (i, fn) in function.list()])
        q = ceil(smax/epsilon/order/2) * order
    pi_discrete = restrict_to_finite_group(function, f=f, order=q)
    pi_pwl = interpolate_to_infinite_group(pi_discrete)
    return q, pi_pwl

def generate_pi_delta(f, delta):
    """
    [Equation 2]

    EXAMPLE::

        sage: logging.disable(logging.WARN)
        sage: pi_delta = generate_pi_delta(2/5, 1/10)
        sage: plot_2d_diagram(pi_delta) # not tested
        sage: minimality_test(pi_delta)
        True
    """
    if not 0 < delta < min([f/2, (1-f)/2]):
        raise ValueError, "Bad parameter delta, needs to be a sufficiently small positive number."
    pi_delta = piecewise_function_from_breakpoints_and_values([0, delta, f-delta, f, f+delta, 1-delta, 1], [0, 1/2, 1/2, 1, 1/2, 1/2, 0])
    return pi_delta

def generate_pi_comb(pi_pwl, epsilon, delta, f=None):
    """
    [Lemma 4]

    EXAMPLE::

        sage: logging.disable(logging.WARN)
        sage: pi_pwl = piecewise_function_from_breakpoints_and_values([0,1/5,2/5,3/5,4/5,1],[0,1/2,1,1/2,1/2, 0])
        sage: minimality_test(pi_pwl)
        True
        sage: plot_2d_diagram(pi_pwl)  # not tested
        sage: pi_comb = generate_pi_comb(pi_pwl, 1/3, 1/10)
        sage: plot_2d_diagram(pi_comb) # not tested
        sage: minimality_test(pi_comb)
        True
    """
    if f is None:
        f = find_f(pi_pwl)
    pi_delta = generate_pi_delta(f, delta)
    pi_comb = (1-epsilon)*pi_pwl + epsilon*pi_delta
    return pi_comb

def find_gamma(fn):
    """
    find gamma>0 such that \Delta\pi(x, y) > gamma
    for all (x,y) in [0,1]^2 \setminus (E_\delta \cup E_f \cup E_{1+f}).

    `fn` may be pi_delta in [Lemma 5] or pi_comb in [Lemma 4],
    with sufficiently small delta as described in the proof of the lemma.

    EXAMPLE::

        sage: logging.disable(logging.WARN)
        sage: pi_delta = generate_pi_delta(2/5, 1/10)
        sage: find_gamma(pi_delta)
        1/2
        sage: pi_pwl = piecewise_function_from_breakpoints_and_values([0,1/5,2/5,3/5,4/5,1],[0,1/2,1,1/2,1/2, 0])
        sage: pi_comb = generate_pi_comb(pi_pwl, 1/3, 1/10)
        sage: find_gamma(pi_comb)
        1/6
    """
    gamma = min(delta_pi(fn, x, y) for (x, y, z, _, _, _) in \
                itertools.chain(generate_type_1_vertices(fn, operator.gt),\
                                generate_type_2_vertices(fn, operator.gt)))
    return gamma

def generate_pi_fill_in(fn, q):
    """
    Return the fill-in function pi_fill_in of `fn` with respect to 1/q\Z and the sublinear function g(r) = max(sp*r, sm*r). [Lemma 6, first step]

    EXAMPLE::

        sage: logging.disable(logging.WARN)
        sage: pi_pwl = piecewise_function_from_breakpoints_and_values([0,1/5,2/5,3/5,4/5,1],[0,1/2,1,1/2,1/2, 0])
        sage: pi_comb = generate_pi_comb(pi_pwl, 1/3, 1/10)
        sage: pi_fill_in = generate_pi_fill_in(pi_comb, 10)
        sage: subadditivity_test(pi_fill_in)
        True
        sage: minimality_test(pi_fill_in)
        False
    """
    return two_slope_fill_in(fn, order=q)

def find_infinite_norm_distance(pi_1, pi_2):
    return max([abs(x) for x in (pi_1 - pi_2).values_at_end_points()])

def generate_pi_sym(fn, f=None):
    """
    Return pi_sym that coincides with `fn` on [0,f/2] and [(1+f)/2, 1],
    and satisfies the symmetry condition.
    [lemma 6, second step]

    Assume the piecewise linear function `fn` satisfies that fn(f/2) = fn((1+f)/2) = 1/2.

    EXAMPLE::

        sage: logging.disable(logging.WARN)
        sage: pi_pwl = piecewise_function_from_breakpoints_and_values([0,1/5,2/5,3/5,4/5,1],[0,1/2,1,1/2,1/2, 0])
        sage: pi_comb = generate_pi_comb(pi_pwl, 1/3, 1/10)
        sage: pi_fill_in = generate_pi_fill_in(pi_comb, 10)
        sage: pi_sym = generate_pi_sym(pi_fill_in)
        sage: symmetric_test(pi_sym, find_f(pi_sym))
        True
        sage: extremality_test(pi_sym)
        True
        sage: find_infinite_norm_distance (pi_sym, pi_pwl)
        1/6
    """
    if f is None:
        f = find_f(fn)
    if not (fn(f/2) == fn((1+f)/2) == 1/2):
        raise ValueError, "Unable to generate pi_sym due to fn(f/2) or fn((1+f)/2) not being 1/2."
    bkpts_left = [x for x in fn.end_points() if x < f/2]
    values_left = [fn(x) for x in bkpts_left]
    bkpts_right = [x for x in fn.end_points() if x > (1+f)/2]
    values_right = [fn(x) for x in bkpts_right]
    bkpts = bkpts_left + [f/2] + [f-x for x in bkpts_left[::-1]] \
            + [1+f-x for x in bkpts_right[-2::-1]] + [(1+f)/2] + bkpts_right
    values = values_left + [1/2] + [1-y for y in values_left[::-1]] \
             + [1-y for y in values_right[-2::-1]] + [1/2] + values_right
    return piecewise_function_from_breakpoints_and_values(bkpts, values)

def symmetric_2_slope_fill_in(function, epsilon, show_plots=False, f=None):
    """
    Given a continuous strong minimal `function` for the Gomory and Johnson infinite group problem with `f` in Q\Z, return an extreme 2-slope function pi_ext that approximates `function` with inifinite norm distance less than epsilon. [Theorem 2].

    EXAMPLES::

        sage: logging.disable(logging.WARN)
        sage: function = piecewise_function_from_breakpoints_and_values([0,1/5,2/5,3/5,4/5,1],[0,1/2,1,1/2,1/2, 0])
        sage: extremality_test(function)
        False
        sage: epsilon = 1/10
        sage: pi_sym = symmetric_2_slope_fill_in(function, epsilon)
        sage: find_infinite_norm_distance(function, pi_sym) <= epsilon
        True
        sage: extremality_test(pi_sym)
        True

    Show plots:
        sage: pi_sym = symmetric_2_slope_fill_in(function, 1/8, True) #not tested
        sage: pi_sym = symmetric_2_slope_fill_in(function, 1/10, True) #not tested
    """
    logging.disable(logging.INFO)
    if f is None:
        f = find_f(function)
    order, pi_pwl = generate_pi_pwl(function, epsilon/3, f=f)
    if is_odd(order) or is_odd(order*f):
        # make sure f/2 and (1+f)/2 are in 1/q*Z
        order = order * 2
    pi_fill_in = generate_pi_fill_in(pi_pwl, order)
    pi_sym = generate_pi_sym(pi_fill_in)
    if subadditivity_test(pi_sym) and (find_infinite_norm_distance(function, pi_sym) <= epsilon):
        if show_plots:
            show_approximations(function, pi_pwl, pi_pwl, pi_fill_in, pi_sym).show()
        #logging.disable(logging.NOTSET)
        return pi_sym
    q = 0
    epsilon_1 = find_infinite_norm_distance(function, pi_pwl)
    while True:
        q += order
        delta = min(f, 1-f)/2 - 1/q
        if pi_pwl.end_points()[1] < delta:
            delta = pi_pwl[1]
        if 1 - pi_pwl.end_points()[-2] < delta:
            delta = 1 - pi_pwl.end_points()[-2]
        pi_comb = generate_pi_comb(pi_pwl, (epsilon-epsilon_1)/2, delta, f=f)
        pi_fill_in = generate_pi_fill_in(pi_comb, q)
        pi_sym = generate_pi_sym(pi_fill_in)
        if (subadditivity_test(pi_sym) is True) and (find_infinite_norm_distance(function, pi_sym) <= epsilon):
            if show_plots:
                g = show_approximations(function, pi_pwl, pi_comb, pi_fill_in, pi_sym)
                show_plot(g, show_plots, tag='sym_2_slope_fill_in_diagram', object=function)
            #logging.disable(logging.NOTSET)
            return pi_sym

def show_approximations(function, pi_pwl, pi_comb, pi_fill_in, pi_sym):
    if pi_pwl == function:
        g = function.plot(color='black', legend_label='pi=pi_pwl', **ticks_keywords(function))
    else:
        g = function.plot(color='black', legend_label='pi', **ticks_keywords(function))
        g = plot_covered_intervals(function, [], uncovered_color='black',legend_label='pi')
        g += pi_pwl.plot(color='gray', legend_label='pi_pwl')
    if not pi_comb == pi_pwl:
        g += pi_comb.plot(color='blue', legend_label='pi_comb')
    g += pi_fill_in.plot(color='orange', legend_label='pi_fill_in')
    g += pi_sym.plot(color='red', legend_label='pi_sym')
    return g
