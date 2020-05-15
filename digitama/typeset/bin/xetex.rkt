#lang typed/racket/base

(require "../tex.rkt")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define xetex-preamble-filter : Tex-Preamble-Filter
  (lambda [line status]
    (cond [(regexp-match? #px"\\\\usepackage\\[utf8\\][{]inputenc[}]" line) (values "\\usepackage{xeCJK}" 'used)]
          [(regexp-match? #px"\\\\newcommand[{]\\\\packageCJK[}]" line) (values #false 'commandset)]
          [(regexp-match? #px"\\\\packageCJK" line) (values #false 'EOF)]
          [else (values line status)])))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(tex-register-renderer 'xetex #:filter xetex-preamble-filter)
(tex-register-renderer 'xelatex #:filter xetex-preamble-filter)