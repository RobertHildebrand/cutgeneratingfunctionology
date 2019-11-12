r"""
Basic polyhedral semialgebraic sets represented as linear systems
"""

from __future__ import division, print_function, absolute_import

from cutgeneratingfunctionology.spam.basic_semialgebraic import BasicSemialgebraicSet_base, BasicSemialgebraicSet_polyhedral
from sage.rings.polynomial.polynomial_ring_constructor import PolynomialRing
from sage.geometry.polyhedron.all import *
import sage.structure.element
import operator

cm = sage.structure.element.get_coercion_model()

# Implement by rewriting code from formulations.sage on branch symbolic_FM. (FourierSystem, ...)

class BasicSemialgebraicSet_polyhedral_linear_system(BasicSemialgebraicSet_polyhedral):

    """
    A closed polyhedral basic semialgebraic set.

    In contrast to ``BasicSemialgebraicSet_polyhedral_ppl_NNC_Polyhedron``, it does not
    eagerly compute the double description, so it is suitable for large linear systems.
    Also it is suitable for arbitrary real fields as the ``base_ring``, such as ``ParametricRealField``.
    """

    def __init__(self, base_ring=None, ambient_dim=None, poly_ring=None, eq=[], lt=[], le=[]):
        r"""
        Initialize a closed polyhedral basic semialgebraic set.

        EXAMPLES::

            sage: import cutgeneratingfunctionology.igp as igp; from cutgeneratingfunctionology.igp import *
            sage: from cutgeneratingfunctionology.spam.basic_semialgebraic_linear_system import *
            sage: logging.disable(logging.INFO)             # Suppress output in automatic tests.
            sage: # One dimensional relu formulation.
            sage: K.<L,U,W,b>=ParametricRealField([QQ(-2),QQ(2),QQ(1),QQ(1/2)])
            sage: Q.<x0,x1,x,y,z>=K[]
            sage: le = [x0+x1-x, -x0-x1+x, -y, W*x0-b*z+b, W*x1-y+b*z, -W*x1+y-b*z, x0+U*z-U, -x0-L*z+L, x1-U*z, -x1+L*z]
            sage: bsa = BasicSemialgebraicSet_polyhedral_linear_system(poly_ring=Q, le=le)
            sage: bsa_eliminated = bsa.coordinate_projection([x0,x1])    # eliminate variable x0,x1.
            sage: bsa_eliminated.le_poly()
            {0,
            ((L - U)~)*z,
            ((-L*W - b)~)*z + (L*W + b)~,
            ((-L + U)~)*z + (L - U)~,
            -y,
            -y + ((L*W + b)~)*z,
            y + ((-U*W - b)~)*z,
            -x + L~,
            -x + y + ((-L*W - b)~)*z + (L*W)~,
            x + (-U)~,
            x + ((-U*W - b)~)*z + b~,
            x - y + (W*b)~,
            x - y + ((U*W + b)~)*z + (-U*W)~}
            
        A non-parametric example::
            sage: D = polytopes.dodecahedron()
            sage: D.dim()
            3
            sage: PR.<x0,x1,x2> = D.base_ring()[]
            sage: bsa = from_polyhedron_to_linear_system(D,poly_ring=PR)
            sage: set(D.vertices()) == set(bsa.to_polyhedron().vertices())
            True
            sage: # project out x1 variable
            sage: proj_mat = matrix([[1,0,0],[0,0,1]])
            sage: D_proj = Polyhedron(vertices = (proj_mat*D.vertices_matrix()).columns())
            sage: bsa_proj = bsa.coordinate_projection([x1])
            sage: set(D_proj.vertices()) == set(bsa_proj.to_polyhedron().vertices())
            True
        """
        if poly_ring is None:
            raise ValueError("must specify the poly_ring")
        polys = list(eq) + list(lt) + list(le)
        #check if the polynomials are actually linear.
        for e in polys:
            if e.degree()>1:
                raise ValueError("only suitable for linear system.")
        if len(polys)>0:
            proper_poly_ring = cm.common_parent(*polys)
            if poly_ring != proper_poly_ring:
                raise ValueError("not a proper poly_ring.")
        if ambient_dim is None:
            ambient_dim = poly_ring.ngens()
        if base_ring is None:
            base_ring = poly_ring.base_ring()
        super(BasicSemialgebraicSet_polyhedral_linear_system, self).__init__(base_ring, ambient_dim)
        self._poly_ring = poly_ring
        self._base_ring = base_ring
        temp_eq = set(eq).copy()
        temp_lt = set(lt).copy()
        temp_le = set(le).copy()
        # remove redundent constant polynomial or check naive infeasibility.
        for e in set(eq):
            if e.parent() != poly_ring:
                if base_ring(e) != base_ring(0):
                    #replace with an invalid inequality.
                    temp_le={poly_ring(1)}
                    temp_eq={}
                    temp_lt={}
                else:
                    temp_eq.remove(e)
        for lt in set(lt):
            if lt.parent() != poly_ring:
                if base_ring(lt) >= base_ring(0):
                    temp_le={poly_ring(1)}
                    temp_eq={}
                    temp_lt={}
                else:
                    temp_lt.remove(lt)
        for le in set(le):
            if le.parent() != poly_ring:
                if base_ring(le) > base_ring(0):
                    temp_le={poly_ring(1)}
                    temp_eq={}
                    temp_lt={}
                else:
                    temp_le.remove(le)
        self._eq = temp_eq
        self._lt = temp_lt
        self._le = temp_le

    def one_step_elimination(self, coordinate_index, bsa_class='linear_system'):
        r"""
        Compute the projection by eliminating ``coordinates``  as a new instance of
        ``BasicSemialgebraicSet_polyhedral_linear_system``.
        """
        # create a new poly_ring with one less generator (coordinate).
        if coordinate_index>=self._poly_ring.ngens():
            raise ValueError("doesn't exist the elimination variable")
        coordinate=self._poly_ring.gens()[coordinate_index]
        variables_names=[str(self._poly_ring.gens()[i]) for i in range(self._poly_ring.ngens()) if i != coordinate_index]
        new_poly_ring=PolynomialRing(self._base_ring,variables_names)
        # create the ring hommorphism
        polynomial_map=[new_poly_ring.gens()[i] for i in range(new_poly_ring.ngens())]
        polynomial_map.insert(coordinate_index,new_poly_ring(0))
        
        new_eq=[]
        new_lt=[]
        new_le=[]
        # try to find a substitution of coordinate in equalities.
        sub=None
        for e in self._eq:
            if e.monomial_coefficient(coordinate) != 0:
                sub = coordinate - e/e.monomial_coefficient(coordinate)
                break
        if sub is None:
            new_eq=self._eq
            lt_lower=[]
            lt_upper=[]
            le_lower=[]
            le_upper=[]
            
            for lt in self._lt:
                if self._base_ring(lt.monomial_coefficient(coordinate))>0:
                    lt_upper.append(lt)
                elif self._base_ring(lt.monomial_coefficient(coordinate))<0:
                    lt_lower.append(lt)
                else:
                    new_lt.append(lt)
            for le in self._le:
                if self._base_ring(le.monomial_coefficient(coordinate))>0:
                    le_upper.append(le)
                elif self._base_ring(le.monomial_coefficient(coordinate))<0:
                    le_lower.append(le)
                else:
                    new_le.append(le)

            # compute less than or equal to inequality
            for l in le_lower:
                for u in le_upper:
                    new_le.append(l*u.monomial_coefficient(coordinate)-(u*l.monomial_coefficient(coordinate)))

            # compute strictly less than inequality
            for l in le_lower:
                for u in lt_upper:
                    new_lt.append(l*u.monomial_coefficient(coordinate)-(u*l.monomial_coefficient(coordinate)))
            for l in lt_lower:
                for u in le_upper:
                    new_lt.append(l*u.monomial_coefficient(coordinate)-(u*l.monomial_coefficient(coordinate)))
            for l in lt_lower:
                for u in lt_upper:
                    new_lt.append(l*u.monomial_coefficient(coordinate)-(u*l.monomial_coefficient(coordinate)))
        else:
            for e in self._eq:
                new_eq.append(e+e.monomial_coefficient(coordinate)*(sub-coordinate))
            for lt in self._lt:
                new_lt.append(lt+lt.monomial_coefficient(coordinate)*(sub-coordinate))
            for le in self._le:
                new_le.append(le+le.monomial_coefficient(coordinate)*(sub-coordinate))

        bsa = BasicSemialgebraicSet_polyhedral_linear_system(base_ring=self._base_ring, ambient_dim=self.ambient_dim(), poly_ring=self._poly_ring, eq=new_eq, lt=new_lt, le=new_le)
        return bsa.section(polynomial_map,bsa_class=bsa_class,poly_ring=new_poly_ring)

    def coordinate_projection(self, coordinates, bsa_class='linear_system'):
        r"""
        Compute the projection after projecting out the ``coordinates`` (a list or tuple of
        indices or variables of ``self.poly_ring``) as a new instance of
        ``BasicSemialgebraicSet_polyhedral_linear_system`` or the given ``bsa_class``.
        """
        res=self
        for c in coordinates:
            if not c in self._poly_ring.gens():
                raise ValueError("Coordinate not found in the polynomial ring")
        elimination_positions=[self._poly_ring.gens().index(c) for c in coordinates]
        for i in range(len(elimination_positions)):
            coordinate_index=elimination_positions[i]
            res = res.one_step_elimination(coordinate_index)
            # update indices
            for j in range(i+1,len(elimination_positions)):
                if elimination_positions[j]>coordinate_index:
                    elimination_positions[j]-=1
        return res
    
    def poly_ring(self):
        r"""
        Return the polynomial ring of self.
        """
        return self._poly_ring

    def eq_poly(self):
        r"""
        Return a list, set, or iterator of the polynomials `f` in equations `f(x) = 0`
        in the description of ``self``.
        
        Together, ``eq_poly``, ``lt_poly``, and ``le_poly`` describe ``self``.
        """
        return self._eq

    def lt_poly(self):
        r"""
        Return a list, set, or iterator of the polynomials `f` in strict inequalities `f(x) < 0`
        in the description of ``self``.
            
        Together, ``eq_poly``, ``lt_poly``, and ``le_poly`` describe ``self``.
        """
        return self._lt

    def le_poly(self):
        r"""
        Return a list, set, or iterator of the polynomials `f` in inequalities `f(x) \leq 0`
        in the description of ``self``.
        
        Together, ``eq_poly``, ``lt_poly``, and ``le_poly`` describe ``self``.
        """
        return self._le

    def add_polynomial_constraint(self, lhs, op):
        """
        ``lhs`` should be a polynomial.
        Add the constraint ``lhs``(x) ``op`` 0,
        where ``op`` is one of ``operator.lt``, ``operator.gt``, ``operator.eq``,
        ``operator.le``, ``operator.ge``.
        """
        if lhs.parent() != self._poly_ring:
            try:
                lhs = self._poly_ring(lhs)
            except TypeError:
                raise TypeError("can not convert lhs into self.poly_ring")
        if lhs.degree() > 1:
            raise ValueError("{} is not a valid linear polynomial.".format(lhs))
        if op == operator.lt:
            self._lt.add(lhs)
        elif op == operator.gt:
            self._lt.add(-lhs)
        elif op == operator.eq:
            self._eq.add(lhs)
        elif op == operator.le:
            self._le.add(lhs)
        elif op == operator.ge:
            self._le.add(-lhs)
        else:
            raise ValueError("{} is not a supported operator".format(op))

    def add_linear_constraint(self, lhs_vector, cst, op):
        """
        Add the constraint ``lhs`` * x + cst ``op`` 0,
        where ``lhs`` is a vector of length ``ambient_dim`` and
        ``op`` is one of ``operator.lt``, ``operator.gt``, ``operator.eq``,
        ``operator.le``, ``operator.ge``.
        """
        if len(lhs_vector) != self._ambient_dim:
            raise ValueError("length of lhs_vector and ambient_dim do not match.")
        lhs=sum(lhs_vector[i]*self.poly_ring().gens()[i] for i in range(len(lhs_vector)))+cst
        self.add_polynomial_constraint(lhs, op)

    def to_polyhedron(self, **kwds):
        # not suitable for Paramatric field??
        if len(self._lt)>0:
            raise ValueError("Contain strict inequalities.")
        ieqs=[]
        eqns=[]
        for le in self._le:
            temp_le = [le.constant_coefficient()] + [le.monomial_coefficient(v) for v in self.poly_ring().gens()]
            ieqs.append([-x for x in temp_le])
        for eq in self._eq:
            eqns.append([eq.constant_coefficient()] + [eq.monomial_coefficient(v) for v in self.poly_ring().gens()])
        return Polyhedron(ieqs=ieqs, eqns=eqns, **kwds)

def from_polyhedron_to_linear_system(p, poly_ring=None):
    """
    Convert a instance of Polyhedron to a instance of BasicSemialgebraicSet_polyhedral_linear_system
    """
    d = p.dim()
    if poly_ring is None:
        poly_ring = PolynomialRing(p.base_ring(), "x", p.ambient_dim())
    bsa = BasicSemialgebraicSet_polyhedral_linear_system(poly_ring = poly_ring)
    for lhs in p.inequalities_list():
        bsa.add_linear_constraint(lhs[1:],lhs[0],operator.ge)
    return bsa

