<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN" [
<!ENTITY dbstyle SYSTEM "html/docbook.dsl" CDATA DSSSL>
]>
<style-sheet>
<style-specification id="html" use="docbook">
<style-specification-body>

(declare-characteristic preserve-sdata?
          "UNREGISTERED::James Clark//Characteristic::preserve-sdata?"
          #f)

(define %generate-book-toc% #t)
(define %generate-book-titlepage% #f)
(define $generate-chapter-toc$ (lambda () #t))
(define ($generate-qandaset-toc$) #t)
(define %header-navigation% #t)
(define %footer-navigation% #t)
(define %gentext-nav-use-tables% #t)
(define %gentext-nav-tblwidth% "100%")
(define %chapter-autolabel% #t)
(define %section-autolabel% #t)
(define %qanda-inherit-numeration% #t)

(define %body-attr%
 (list
   (list "BGCOLOR" "#000000")
   (list "TEXT" "#FFFFFF")
   (list "LINK" "#6666FF")
   (list "VLINK" "#999999")
   (list "ALINK" "#6666FF")))

(define %html-ext% ".html")

(define (gentext-en-nav-prev prev) 
  (make sequence (literal "<<< Previous")))

(define (gentext-en-nav-next next)
  (make sequence (literal "Next >>>")))

</style-specification-body>
</style-specification>
<external-specification id="docbook" document="dbstyle">
</style-sheet>




