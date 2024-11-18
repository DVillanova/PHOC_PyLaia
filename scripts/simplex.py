#!/usr/bin/python2

# **************************************
# Author: Vicente Alabau
# Date:   26-05-2009
# Summary: Script to optimize parameters
# **************************************


from scipy.optimize import fmin
import numpy
from numpy import atleast_1d, eye, mgrid, argmin, zeros, shape, empty, \
     squeeze, vectorize, asarray, absolute, sqrt, Inf, asfarray, isinf


import os, sys, random, getopt, re
from popen2 import *
from math import *

def wrap_function(function, args):
    ncalls = [0]
    def function_wrapper(x):
        ncalls[0] += 1
        return function(x, *args)
    return ncalls, function_wrapper


def simplex(func, x0, args=(), xtol=1e-4, ftol=1e-4, maxiter=None, maxfun=None,
         full_output=0, disp=1, retall=0, callback=None, delt = None):
    """Minimize a function using the downhill simplex algorithm.

    :Parameters:

      func : callable func(x,*args)
          The objective function to be minimized.
      x0 : ndarray
          Initial guess.
      args : tuple
          Extra arguments passed to func, i.e. ``f(x,*args)``.
      callback : callable
          Called after each iteration, as callback(xk), where xk is the
          current parameter vector.

    :Returns: (xopt, {fopt, iter, funcalls, warnflag})

      xopt : ndarray
          Parameter that minimizes function.
      fopt : float
          Value of function at minimum: ``fopt = func(xopt)``.
      iter : int
          Number of iterations performed.
      funcalls : int
          Number of function calls made.
      warnflag : int
          1 : Maximum number of function evaluations made.
          2 : Maximum number of iterations reached.
      allvecs : list
          Solution at each iteration.

    *Other Parameters*:

      xtol : float
          Relative error in xopt acceptable for convergence.
      ftol : number
          Relative error in func(xopt) acceptable for convergence.
      maxiter : int
          Maximum number of iterations to perform.
      maxfun : number
          Maximum number of function evaluations to make.
      full_output : bool
          Set to True if fval and warnflag outputs are desired.
      disp : bool
          Set to True to print convergence messages.
      retall : bool
          Set to True to return list of solutions at each iteration.

    :Notes:

        Uses a Nelder-Mead simplex algorithm to find the minimum of
        function of one or more variables.

    """
    fcalls, func = wrap_function(func, args)
    x0 = asfarray(x0).flatten()
    N = len(x0)
    if not delt: delt = [0.5]*N 
    rank = len(x0.shape)
    if not -1 < rank < 2:
        raise ValueError,"Initial guess must be a scalar or rank-1 sequence."
    if maxiter is None:
        maxiter = N * 200
    if maxfun is None:
        maxfun = N * 200

    rho = 1; chi = 2; psi = 0.5; sigma = 0.5;
    one2np1 = range(1,N+1)

    if rank == 0:
        sim = numpy.zeros((N+1,), dtype=x0.dtype)
    else:
        sim = numpy.zeros((N+1,N), dtype=x0.dtype)
    fsim = numpy.zeros((N+1,), float)
    sim[0] = x0
    if retall:
        allvecs = [sim[0]]
    fsim[0] = func(x0)

    for k in range(0,N):
        y = numpy.array(x0,copy=True)
        if y[k] != 0:
            y[k] = (1+delt[k])*y[k]
        else:
            y[k] = delt[k]

        sim[k+1] = y
        f = func(y)
        fsim[k+1] = f

    ind = numpy.argsort(fsim)
    fsim = numpy.take(fsim,ind,0)
    # sort so sim[0,:] has the lowest function value
    sim = numpy.take(sim,ind,0)

    iterations = 1

    while (fcalls[0] < maxfun and iterations < maxiter):
        if (max(numpy.ravel(abs(sim[1:]-sim[0]))) <= xtol \
            and max(abs(fsim[0]-fsim[1:])) <= ftol):
            break

        xbar = numpy.add.reduce(sim[:-1],0) / N
        xr = (1+rho)*xbar - rho*sim[-1]
        fxr = func(xr)
        doshrink = 0

        if fxr < fsim[0]:
            xe = (1+rho*chi)*xbar - rho*chi*sim[-1]
            fxe = func(xe)

            if fxe < fxr:
                sim[-1] = xe
                fsim[-1] = fxe
            else:
                sim[-1] = xr
                fsim[-1] = fxr
        else: # fsim[0] <= fxr
            if fxr < fsim[-2]:
                sim[-1] = xr
                fsim[-1] = fxr
            else: # fxr >= fsim[-2]
                # Perform contraction
                if fxr < fsim[-1]:
                    xc = (1+psi*rho)*xbar - psi*rho*sim[-1]
                    fxc = func(xc)

                    if fxc <= fxr:
                        sim[-1] = xc
                        fsim[-1] = fxc
                    else:
                        doshrink=1
                else:
                    # Perform an inside contraction
                    xcc = (1-psi)*xbar + psi*sim[-1]
                    fxcc = func(xcc)

                    if fxcc < fsim[-1]:
                        sim[-1] = xcc
                        fsim[-1] = fxcc
                    else:
                        doshrink = 1

                if doshrink:
                    for j in one2np1:
                        sim[j] = sim[0] + sigma*(sim[j] - sim[0])
                        fsim[j] = func(sim[j])

        ind = numpy.argsort(fsim)
        sim = numpy.take(sim,ind,0)
        fsim = numpy.take(fsim,ind,0)
        if callback is not None:
            callback(sim[0])
        iterations += 1
        if retall:
            allvecs.append(sim[0])

    x = sim[0]
    fval = min(fsim)
    warnflag = 0

    if fcalls[0] >= maxfun:
        warnflag = 1
        if disp:
            print "Warning: Maximum number of function evaluations has "\
                  "been exceeded."
    elif iterations >= maxiter:
        warnflag = 2
        if disp:
            print "Warning: Maximum number of iterations has been exceeded"
    else:
        if disp:
            print "Optimization terminated successfully."
            print "         Current function value: %f" % fval
            print "         Iterations: %d" % iterations
            print "         Function evaluations: %d" % fcalls[0]


    if full_output:
        retlist = x, fval, iterations, fcalls[0], warnflag
        if retall:
            retlist += (allvecs,)
    else:
        retlist = x
        if retall:
            retlist = (x, allvecs)

    return retlist


space_re = re.compile(r'\s+')
var_get_re = re.compile(r'{(\S+?)}')
var_del_re = re.compile(r'{\S+?}')

def parse_cmd(arg):
  x0 = []
  delt = []
  for x_i in var_get_re.findall(arg):
    values = x_i.split(":")
    x0.append(float(values[0]))
    if len(values) > 1:
      delt.append(float(values[1]))
    else:
      delt.append(0.5)
  cmd = "%s".join(var_del_re.split(arg))
  return (cmd, x0, delt)

def cmd_function(x):  
  if verbose > 0: print "running: %s" % (command % tuple(x))
  (output, _) = popen2(command % tuple(x))
  res = space_re.split(output.readline())
  print "args = %s, result = %s" % (str(x), res)
  sys.stdout.flush()
  return sign*float(res[0])


##### MAIN #####
def usage():
  print "usage: %s [-h] [-v] [-m] [-M] [-t] [-f] command" % __file__


verbose = 0
ftol = 0.01
xtol = 0.01
sign = 1.0 # minimise

try:
  opts, args = getopt.getopt(sys.argv[1:], "hvmMt:f:", ["minimise", "maximise", "xtol:", "ftol", "help", "verbose"])
except getopt.GetoptError:
  # print help information and exit:
  usage()
  sys.exit(2)

for o, a in opts:
  if o in ("-m", "--minimise"):
    sign = 1.0
  if o in ("-M", "--maximise"):
    sign = -1.0
  if o in ("-t", "--xtol"):
    xtol = float(1)
  if o in ("-f", "--ftol"):
    ftol = float(1)
  if o in ("-v", "--verbose"):
    verbose = 1
  if o in ("-h", "--help"):
    usage()
    sys.exit()

if len(args) < 1:
  usage()
  sys.exit()


(command, x0, delt) = parse_cmd(args[0])

xopt = simplex(cmd_function, x0, ftol=ftol, xtol=xtol, delt=delt)

print "Optimum parameters: " + str(xopt)
print "Optimum command: " + command % tuple(xopt) 



