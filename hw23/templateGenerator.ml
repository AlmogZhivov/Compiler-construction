(* #lang racket
(define pattern
  (lambda (e)
    (cond
      ((boolean? e)
        (if e "ScmBoolean true" "ScmBoolean false"))
      ((null? e) "ScmNil")
      ((char? e) (format "ScmChar '~a' " e))
      ((symbol? e) (format "ScmSymbol \"~a\"" e))
      ((string? e) (format "ScmString \"~a\"" e))
      ((integer? e) (format "ScmNumber (ScmInteger ~a)" e))
      ((rational? e) (format "ScmNumber (ScmReal ~a)" e))
      ((pair? e)
         (format "ScmPair(~a,~a)"
                  (pattern (car e))
                  (pattern (cdr e))))
      ((vector? e)
       (format "ScmVector [~a]"
               (foldr (lambda (v lst) (string-append v ";" lst)) ""
                           (map pattern (vector->list e)))))
      (else (error 'pattern (format "Unsupported type: ~a" e)))))) *)