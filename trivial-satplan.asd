(asdf:defsystem trivial-satplan
  :description "SMT-based planner"
  :depends-on ("alexandria" "cl-ppcre")
  :components ((:file "package")
               (:file "util" :depends-on ("package"))
               (:file "smtlib" :depends-on ("util"))
               (:file "pddl" :depends-on ("util"))
               (:file "planner" :depends-on ("util" "pddl" "smtlib"))))
