(in-package :trivial-satplan)

(defun TODO (thing)
  (error "Unimplemented: ~A" thing))

(defun collect-args (objects arity)
  (if (zerop arity)
      (list nil)
      (loop for o in objects
         nconc
           (loop for args in (collect-args objects (1- arity))
              collect (cons o args)))))

(defun mangle (exp i)
  "Name-mangle an expression into an unrolled variable at step i.
EXP: an s-expression
I: The step to unroll at"
  (format nil "~{~A~^_~}_~D" exp i))

(defun format-state-variable (predicate step)
  "Name-mangle a predicate"
  (mangle predicate step))

(defun format-op (op args step)
  "Name-mangle an action"
  (mangle (cons op args) step))

(defun unmangle-op (mangled)
  "Un-mangle a mangled name back to the s-expression."
  (let ((list (ppcre:split "_" mangled)))
    (cons (parse-integer (lastcar list))
          (loop for x on list
             for a = (car x)
             when (cdr x)
             collect
             a))))


(defun create-state-variables (predicates objects)
  "Construct the state variables (fluents) for PREDICATES and OBJECTS.

  The result is not unrolled.

RETURNS: List of fluents as s-expression."
  (loop for p in predicates
     append
       (loop for args in (collect-args objects (predicate-arity p))
          collect (TODO 'create-state-variables))))

(defstruct concrete-action
  name
  actual-arguments
  precondition
  effect)

(defun format-concrete-action (op step)
  (format-op (concrete-action-name op)
             (concrete-action-actual-arguments op)
             step))

(defun exp-args-alist (dummy-args actual-args)
  "Find alist for argument replacement"
  (assert (= (length dummy-args) (length actual-args)))
  (loop
     for d in dummy-args
     for a in actual-args
     collect (cons d a)))

(defun smt-concrete-operators (operators objects)
  (let ((result))
    (dolist (operator (operators-actions operators))
      (dolist (args (collect-args objects
                                  (length (action-parameters operator))))
        (let ((arg-alist (exp-args-alist (action-parameters operator)
                                         args)))
          (push (make-concrete-action
                 :name (action-name operator)
                 :actual-arguments args
                 :precondition (sublis arg-alist (action-precondition operator))
                 :effect (sublis arg-alist (action-effect operator)))
                result))))
    result))

(defun concrete-action-modifies-varable-p (operator variable)
  (let ((not-variable (list 'not variable)))
    (destructuring-bind (-and &rest things) (concrete-action-effect operator)
      (check-symbol -and 'and)
      (labels ((rec (rest)
                 (when rest
                   (let ((x (first rest)))
                     (if (or (equal x variable)
                             (equal x not-variable))
                         t
                         (rec (cdr rest)))))))
        (rec things)))))

(defun concrete-action-modified-variables (operator)
  (destructuring-bind (-and &rest things) (concrete-action-effect operator)
    (check-symbol -and 'and)
    (loop for exp in things
       collect
         (destructuring-case exp
           ((not x) x)
           ((t &rest rest) (declare (ignore rest))
            exp)))))

(defun sat-frame-axioms (state-vars concrete-operators step)
  "Construct the frame axioms in the SATPlan encoding.

Returns: List of s-expressions."
  (let ((hash (make-hash-table :test #'equal))) ;; hash: variable => (list modifiying-operators)
    ;; note modified variables
    (dolist (op concrete-operators)
      (dolist (v (concrete-action-modified-variables op))
        (push op (gethash v hash))))
    ;; collect axioms
    (loop for var in state-vars
       collect (TODO 'sat-frame-axioms))))


(defun sat-initial-state  (state-vars facts)
  "Construct assertions for the initial state.

  RETURNS: list of s-expressions (assertions)."
  (let* ((initial-true (facts-init facts))
         (initial-false (set-difference  state-vars initial-true :test #'equal)))
    (TODO 'sat-initial-state)))

(defun sat-plan-operator (op i)
  "Construct operator encoding (transfer-function) for a single operarator at step i.

RETURNS: An s-expression."
  ;; HINT: use REWRITE-EXP
  (TODO 'sat-plan-operator))

(defun sat-plan-exclusion (concrete-operators op i)
  "Construct exclusion axioms or a single operarator at step i.

RETURNS: An s-expression."
  (TODO 'sat-plan-exclusion))


(defun sat-plan-encode (operators facts steps)
  "Construct the SATPlan encoding of the domain.

Return: (VALUES SAT-VARIABLES ASSERTIONS ACTION-VARIABLES)

SAT-VARIABLES: The Boolean variables for the unrolled domain
ASSERTIONS: Individual clauses of the constraint formula
ACTIONS-VARIABLES: The subset of SAT-VARIABLES for acotions
"
  (let (
        ;; propositionalized, but not unrolled, fluents
        (state-vars (create-state-variables (operators-predicates operators)
                                            (facts-objects facts)))
        ;; propositionalized, but not unrolled, action variables
        (concrete-operators (smt-concrete-operators operators  (facts-objects facts)))
        variables   ; output
        assertions  ; output
        actions)    ; output
    (labels ((add-var (x) (push x variables))
             (add-action (x)
               (add-var x)
               (push x actions))
             (add-assert (x) (push x assertions))
             (add-asserts (list)
               (map nil #'add-assert list)))

      ;; per-step state variables
      (dotimes (i (1+ steps))
        (dolist (v state-vars)
          (add-var (format-state-variable v i))))

      ;; per-step action variables
      (dotimes (i  steps)
        (dolist (op concrete-operators)
          (let ((v (format-concrete-action op i)))
            (add-action v))))

      ;; initial state
      (add-asserts (sat-initial-state state-vars facts))

      ;; goal state
      (let* ((goal (facts-goal facts)))
        (add-assert (rewrite-exp goal steps)))

      ;; operator encodings
      (dotimes (i steps)
        (dolist (op concrete-operators)
          (add-assert (sat-plan-operator op i))))

      ;; exclusion axioms
      (dotimes (i steps)
        (dolist (op concrete-operators)
          (add-assert (sat-plan-exclusion concrete-operators op i))))

      ;; frame axioms
      (dotimes (i steps)
        (add-asserts (sat-frame-axioms state-vars concrete-operators i))))
    (values variables assertions actions)))



(defun smt-plan-encode (operators facts steps)
  (multiple-value-bind (variables assertions actions)
      (sat-plan-encode operators facts steps)
    (values (append (loop for x in variables
                       collect (smt-declare-fun  x () 'bool))
                    (loop for x in assertions
                       collect (smt-assert x)))

            actions)))

(defun smt-parse-assignments (assignments)
  (let ((plan))
    (dolist (x assignments)
      (destructuring-bind (var value) x
        (when (eq 'true value)
          (push (unmangle-op (string var)) plan))))
    (sort plan (lambda (a b) (< (car a) (car b))))))


(defun smt-plan (operator-file facts-file
                 &key
                   (steps 1)
                   (max-steps 10)
                   (smt-file "/tmp/trivial-satplan.smt2")
                   (result-file "/tmp/trivial-satplan-result"))
  (let ((operators (load-operators operator-file))
        (facts (load-facts facts-file)))
    (labels ((rec (steps)
               (format *error-output* "~&Unrolling for step ~D...~%" steps)
               (multiple-value-bind (assignments is-sat)
                   (multiple-value-bind (stmts vars)
                       (smt-plan-encode operators facts steps)
                     (smt-run stmts vars
                              :smt-file smt-file
                              :result-file result-file))
                 (cond
                   (is-sat
                    (smt-parse-assignments assignments))
                   ((< steps max-steps)
                    (rec (1+ steps)))
                   (t nil)))))
    (rec steps))))
