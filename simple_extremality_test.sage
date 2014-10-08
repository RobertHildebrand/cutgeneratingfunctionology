# Make sure current directory is in path.  
# That's not true while doctesting (sage -t).
if '' not in sys.path:
    sys.path = [''] + sys.path

from igp import *

def generate_perturbations_simple(fn, show_plots=False, f=None, oversampling=3, order=None):
    """
    Generate (with "yield") perturbations for `simple_finite_dimensional_extremality_test`. 
    """
    if f is None:
        f = find_f(fn, no_error_if_not_minimal_anyway=True)
    field = fn(0).parent().fraction_field()
    grid_nb = finite_group_order_from_function_f_oversampling_order(fn, f=f, oversampling=oversampling, order=order)
    grid = field(1 / grid_nb)
    pts = [grid * i for i in range(grid_nb)]
    # or range(grid_nb+1)? It doesn't matter for continuous function, since if minimality_test is pass, fn(1) must equal to 0
    values = [fn(pt) for pt in pts]
    # values = [fn(i / grid_nb) for i in range(grid_nb)]
    f_grid_index = int(f * grid_nb)
    basis_vects = VectorSpace(field,grid_nb).basis()
    # equation pi(0) = 0 and equation pi(f) = 1.
    equation_list = [list(basis_vects[0]), list(basis_vects[f_grid_index])]
    for i in range(grid_nb):
        for j in range(i, grid_nb, 1):
            k = (i + j) % grid_nb
            if values[i] + values[j] == values[k]:
                equation = list(basis_vects[i] + basis_vects[j] - basis_vects[k])
                equation_list.append(equation)
    equations = matrix(field, equation_list, sparse=True)
    # FIXME: When the grid is fine or there are many additive pairs, the number of equations is enormous. Very slow.
    # Maybe, should use the fact that equations is a sparse matrix.
    # Or compute rank instead?  extreme iff equations.rank() == grid_nb
    solutions = equations.right_kernel().basis()
    logging.info("Solution space has dimension %s" % len(solutions))
    # FIXME: cache data up to here.
    for sol_index in range(len(solutions)):
        solution = list(solutions[sol_index])
        if fn.is_discrete():
            perturbation = discrete_function_from_points_and_values(pts+[1], solution+[0], field)
        elif fn.is_continuous():
            perturbation = piecewise_function_from_breakpoints_and_values(pts+[1], solution+[0], field)
        else:
             # FIXME: Handle the discontinuous case properly !
            perturbation = piecewise_function_from_breakpoints_and_values(pts+[1], solution+[0], field)
        yield perturbation

def simple_finite_dimensional_extremality_test(fn, show_plots=False, f=None, oversampling=3, order=None, show_all_perturbations=False):
    """
    Simple finite dimensional extremality test that does not go
    through the whole machinery of covered intervals etc., but rather
    sets up a grid 1/mq, where q is the lcm of the breakpoint
    denominator and m is the `oversampling` factor (we prove in
    Equivariant I that m = 4 always is enough; in the survey we prove
    that, in fact, m = 3 (the default) suffices.

    Instead of the `oversampling` factor, the code also allows to
    specify a different grid; this is particularly useful for the
    irrational case.

    EXAMPLES::

        sage: logging.disable(logging.INFO) # to disable output in automatic tests.
        sage: h = piecewise_function_from_breakpoints_and_values([0, 1/2, 1], [0, 1, 0])
        sage: simple_finite_dimensional_extremality_test(h, False)
        True
        sage: simple_finite_dimensional_extremality_test(drlm_not_extreme_1(), False, oversampling=1)
        True
        sage: simple_finite_dimensional_extremality_test(drlm_not_extreme_1(), False, oversampling=2)
        False
        sage: simple_finite_dimensional_extremality_test(minimal_has_uncovered_interval(), False)
        False
        sage: simple_finite_dimensional_extremality_test(drlm_not_extreme_2(), False)
        False
    """
    if show_all_perturbations is None:
        show_all_perturbations = show_plots
    if f is None:
        f = find_f(fn, no_error_if_not_minimal_anyway=True)
    if not minimality_test(fn, show_plots=show_plots, f=f):
        logging.info("Not minimal, thus NOT extreme.")
        return False

    seen_perturbation = False
    for index, perturbation in enumerate(generate_perturbations_simple(fn, show_plots=show_plots, f=f, oversampling=oversampling, order=order)):
        check_perturbation(fn, perturbation,
                           show_plots=show_plots, show_plot_tag='perturbation-%s' % (index + 1),
                           legend_title="Basic perturbation %s" % (index + 1))
        if not seen_perturbation:
            seen_perturbation = True
            logging.info("Thus the function is NOT extreme.")
            if not show_all_perturbations:
                break

    if not seen_perturbation:
        if fn.is_discrete():
            logging.info("Thus the function is extreme.")
        elif oversampling is not None and oversampling >= 3 and order is None and fn.is_continuous():
            logging.info("Because oversampling >= 3, this means that the function is extreme.")
    return not seen_perturbation
