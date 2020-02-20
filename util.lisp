(in-package :trivial-satplan)

(defun load-sexp (filename)
  "Read a single s-expression from a file"
  (with-open-file (s filename :direction :input)
    (read s)))

(defun check-symbol (value required)
  "Check symbol name of `VALUE' is string= to symbol name of `REQUIRED'"
  (unless (string= (string value) (string required))
    (error "Symbol mismatch on ~A, required ~A" value required)))


(defun apply-rewrite-exp (function exp)
  (etypecase exp
    (atom (funcall function exp))
    (list
     (destructuring-case exp
       (((and or not) &rest rest)
        (cons (car exp)
              (loop for exp in rest collect (apply-rewrite-exp function exp))))
       ((t &rest rest) (declare (ignore rest))
        (funcall function exp))))))

(defun rewrite-exp (exp step)
  (apply-rewrite-exp (lambda (exp)
                       (format-state-variable exp step))
                     exp))

(defun var-set-insert (set var)
  (union set (list var) :test #'equal))

(defun exp-variables (exp &optional set)
  "Return the set of variables in `EXP'."
  (labels ((rec (vars exp)
             (etypecase exp
               (atom (union vars (list exp) :test #'equal))
               (list
                (destructuring-case exp
                  (((and or not) &rest rest)
                   (reduce #'rec rest :initial-value vars))
                  ((t &rest rest) (declare (ignore rest))
                   (var-set-insert vars exp)))))))
    (rec set exp)))

(defun exp-list-variables (exps)
  (reduce #'exp-variables exps :initial-value nil))
