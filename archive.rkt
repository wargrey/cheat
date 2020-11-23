#lang typed/racket/base

(provide (all-defined-out))
(provide ZIP-Entry zip-entry? sizeof-zip-entry)
(provide ZIP-Directory zip-directory? sizeof-zip-directory)

(require "digitama/bintext/zip.rkt")
(require "digitama/ioexn.rkt")

(require "filesystem.rkt")
(require "port.rkt")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-file-reader zip-list-directory #:+ (Listof ZIP-Directory) #:binary
  (lambda [/dev/zipin src]
    (define maybe-sigoff (zip-seek-signature /dev/zipin))

    (cond [(not maybe-sigoff) (throw-signature-error /dev/zipin 'zip-directory-list "not a ZIP file")]
          [else (let* ([eocdr (read-zip-end-of-central-directory /dev/zipin)]
                       [cdir-offset (zip-end-of-central-directory-cdir-offset eocdr)])
                  (let ls ([sridc : (Listof ZIP-Directory) null]
                           [pos : Natural (port-seek /dev/zipin cdir-offset)])
                    (cond [(>= pos maybe-sigoff) (reverse sridc)]
                          [else (let ([cdir (read-zip-directory /dev/zipin)])
                                  (ls (cons cdir sridc)
                                      (file-position /dev/zipin)))])))])))

(define-file-reader zip-list-entry #:+ (Listof ZIP-Entry) #:binary
  (lambda [/dev/zipin src]
    (define maybe-sigoff (zip-seek-signature /dev/zipin))

    (cond [(not maybe-sigoff) (throw-signature-error /dev/zipin 'zip-entry-list "not a ZIP file")]
          [else (let* ([eocdr (read-zip-end-of-central-directory /dev/zipin)])
                  (let ls ([seirtne : (Listof ZIP-Entry) null]
                           [cdir-pos : Natural (zip-end-of-central-directory-cdir-offset eocdr)])
                    (cond [(>= cdir-pos maybe-sigoff) (reverse seirtne)]
                          [else (let ([cdir (read-zip-directory /dev/zipin cdir-pos)])
                                  (ls (cons (read-zip-entry /dev/zipin (zip-directory-relative-offset cdir)) seirtne)
                                      (+ cdir-pos (sizeof-zip-directory cdir))))])))])))

(define zip-list : (-> (U Input-Port Path-String (Listof ZIP-Directory) (Listof ZIP-Entry)) (Listof String))
  (lambda [/dev/zipin]
    (for/list ([lst (in-list (zip-list* /dev/zipin))])
      (car lst))))

(define zip-list* : (-> (U Input-Port Path-String (Listof ZIP-Directory) (Listof ZIP-Entry)) (Listof (List String Index Index)))
  (lambda [/dev/zipin]
    (define entries : (U (Listof ZIP-Directory) (Listof ZIP-Entry))
      (cond [(input-port? /dev/zipin) (zip-list-directory /dev/zipin)]
            [(not (list? /dev/zipin)) (zip-list-directory* /dev/zipin)]
            [else /dev/zipin]))
    
    (for/list ([e (in-list entries)])
      (if (zip-directory? e)
          (list (bytes->string/utf-8 (zip-directory-filename e)) (zip-directory-csize e) (zip-directory-rsize e))
          (list (bytes->string/utf-8 (zip-entry-filename e)) (zip-entry-csize e) (zip-entry-rsize e))))))

(define zip-content-size : (-> (U Input-Port Path-String (Listof ZIP-Directory) (Listof ZIP-Entry)) Natural)
  (lambda [/dev/zipin]
    (define-values (csize rsize) (zip-content-size* /dev/zipin))
    rsize))

(define zip-content-size* : (-> (U Input-Port Path-String (Listof ZIP-Directory) (Listof ZIP-Entry)) (Values Natural Natural))
  (lambda [/dev/zipin]
    (define entries : (U (Listof ZIP-Directory) (Listof ZIP-Entry))
      (cond [(input-port? /dev/zipin) (zip-list-directory /dev/zipin)]
            [(not (list? /dev/zipin)) (zip-list-directory* /dev/zipin)]
            [else /dev/zipin]))
    
    (for/fold ([csize : Natural 0] [rsize : Natural 0])
              ([e (in-list entries)])
      (if (zip-directory? e)
          (values (+ csize (zip-directory-csize e)) (+ rsize (zip-directory-rsize e)))
          (values (+ csize (zip-entry-csize e)) (+ rsize (zip-entry-rsize e)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;