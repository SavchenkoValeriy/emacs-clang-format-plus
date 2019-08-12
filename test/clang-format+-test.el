;;; clang-format+-test.el --- Tests for clang-format+ -*- lexical-binding: t; -*-

(require 'clang-format+)

(ert-deftest clang-format+:basic-test ()
  (with-temp-buffer
    (c++-mode)
    (clang-format+-mode)
    (insert "\nclass A    {\n\n\n};\n")
    (clang-format+-before-save)
    (should (equal (clang-format+:buffer-string)
                   "\nclass A {};\n"))))

(ert-deftest clang-format+:modified-test ()
  (with-temp-buffer
    (switch-to-buffer (current-buffer))
    (insert "\nclass A    {\n\nint foo () {\n\n};\n};\n")
    (c++-mode)
    (clang-format+-mode)
    (previous-line 3)
    (insert "\n\n\n")
    (clang-format+-before-save)
    (should (equal (clang-format+:buffer-string)
                   "\nclass A    {\n\n  int foo(){\n\n  };\n};\n"))))

(ert-deftest clang-format+:apply-to-all-test ()
  (let ((clang-format+-apply-to-modifications-only nil)
        (clang-format-style "llvm"))
    (with-temp-buffer
      (switch-to-buffer (current-buffer))
      (insert "\nclass A    {\n     public:\nint foo () {\n\n};\n};\n")
      (c++-mode)
      (clang-format+-mode)
      (previous-line 3)
      (insert "\n\n\n")
      (clang-format+-before-save)
      (should (equal (clang-format+:buffer-string)
                     "\nclass A {\npublic:\n  int foo(){\n\n  };\n};\n")))))

(ert-deftest clang-format+:no-definition-test ()
  (let ((clang-format+-apply-to-modified-definition nil))
    (with-temp-buffer
      (switch-to-buffer (current-buffer))
      (insert "\nclass A    {\n\npublic:\n\n};\n")
      (c++-mode)
      (clang-format+-mode)
      (previous-line 2)
      (insert "        void       foo      ()   {  }")
      (clang-format+-before-save)
      (should (equal (clang-format+:buffer-string)
                     "\nclass A    {\n\npublic:\n  void foo() {}\n};\n")))))

(ert-deftest clang-format+:in-namespace-test ()
  (let ((clang-format-style "llvm"))
    (with-temp-buffer
      (switch-to-buffer (current-buffer))
      (insert "\nnamespace a    {\n\nvoid    foo   (   ) {}\n\n\n\n\n\n\n}\n")
      (c++-mode)
      (clang-format+-mode)
      (previous-line 5)
      (insert "        void       bar      ()   {  }")
      (clang-format+-before-save)
      (should
       (equal
        (clang-format+:buffer-string)
        "\nnamespace a    {\n\nvoid    foo   (   ) {}\n\nvoid bar() {}\n}\n")))))

;;; clang-format+-test.el ends here
