import os
import re
import ast

def check_build_context_usage(directory):
    """
    Recursively checks for potential misuse of BuildContext across async gaps
    in Dart files within the given directory and its subdirectories.

    Args:
        directory: The starting directory to search.
    """
    for root, _, files in os.walk(directory):
        for filename in files:
            if filename.endswith(".dart"):
                filepath = os.path.join(root, filename)
                check_file_for_context_issues(filepath)

def check_file_for_context_issues(filepath):
    """
    Analyzes a single Dart file for potential BuildContext misuse after async calls.

    Args:
        filepath: The path to the Dart file.
    """
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            source_code = f.read()

        tree = ast.parse(source_code, filename=filepath, type_comments=False)  # Parse the Dart code into an AST

        visitor = BuildContextVisitor(filepath)
        visitor.visit(tree)


    except FileNotFoundError:
        print(f"Error: File not found: {filepath}")
    except SyntaxError as e:
        print(f"Syntax error in {filepath}: {e}")
    except Exception as e:
        print(f"Error processing {filepath}: {e}")



class BuildContextVisitor(ast.NodeVisitor):
    """
    An AST visitor class to find potential BuildContext misuse.
    """

    def __init__(self, filepath):
        super().__init__()
        self.filepath = filepath
        self.context_variables = set()
        self.async_depth = 0
        self.inside_build_method = False
        # Keep track of line numbers where async calls are made.  This is crucial
        # for correctly identifying subsequent context usage.
        self.async_call_lines = []

    def visit_FunctionDef(self, node):
        """
        Handles function definitions, checking if it's a build method.
        """
        # Check if the function's name is "build" and it has a BuildContext parameter
        if node.name == "build":
            for arg in node.args.args:
                if arg.arg == 'context':
                    if arg.annotation and isinstance(arg.annotation, ast.Name) and arg.annotation.id == 'BuildContext':
                        self.inside_build_method = True
                        break  # We've found BuildContext, no need to check further

        self.generic_visit(node) # Continue traversing the tree inside the function
        self.inside_build_method = False # reset the flag when exit function.

    def visit_AwaitExpr(self, node):
        """
        Handles 'await' expressions, increasing the async depth.
        """
        # Store the line number of the await expression
        self.async_call_lines.append(node.lineno)

        self.async_depth += 1
        self.generic_visit(node)  # Continue to nested nodes within the await
        self.async_depth -= 1

        if self.async_depth == 0:
            self.async_call_lines = [] # Reset when we exit a complete async block

    def visit_Name(self, node):
        """
        Handles variable usage (identifiers).
        """
        if self.async_depth > 0 and self.inside_build_method:
            is_context_usage = (
                node.id == 'context' or  # Direct 'context' usage
                (node.id in self.context_variables and not self.is_guarded_by_mounted(node.lineno)) # Usage via a variable
            )

            if is_context_usage and node.lineno > min(self.async_call_lines, default=0):
                print(f"Potential BuildContext misuse after async gap in {self.filepath}:{node.lineno}")


        self.generic_visit(node)


    def visit_Assign(self, node):
        """Handles assignment statements (to track variables holding context)"""
        # Check the right-hand side (value being assigned) first.
        self.visit(node.value)

        # Check if the right-hand side of the assignment is a BuildContext
        if isinstance(node.value, ast.Name) and node.value.id == 'context':
            for target in node.targets: # Left side of assignment
                if isinstance(target, ast.Name): # Variable assigned to context
                    self.context_variables.add(target.id)

        # Check assignments where context might be passed indirectly:
        elif isinstance(node.value, ast.Call):
          if isinstance(node.value.func, ast.Name) and node.value.func.id == 'Provider.of':
              # Provider.of<SomeType>(context) pattern.
              for arg in node.value.args:
                if isinstance(arg, ast.Name) and arg.id == 'context':
                    for target in node.targets:
                        if isinstance(target, ast.Name):
                            self.context_variables.add(target.id)

        for target in node.targets:
            self.visit(target)



    def visit_If(self, node):
        """
        Handles 'if' statements, particularly for 'mounted' checks.
        """
        # Check for `if (!mounted) return;` pattern
        if (
            isinstance(node.test, ast.UnaryOp) and
            isinstance(node.test.op, ast.Not) and
            isinstance(node.test.operand, ast.Name) and
            node.test.operand.id == "mounted" and
            len(node.body) == 1 and
            isinstance(node.body[0], ast.Return)
        ):
            # If we find a mounted check, remove lines within this 'if' block from async_call_lines
            for line_no in range(node.lineno, node.body[0].lineno + 1):
                if line_no in self.async_call_lines:
                    self.async_call_lines.remove(line_no)

        self.generic_visit(node)


    def is_guarded_by_mounted(self, lineno):
        """
        Check if a line number is within the scope of an if(!mounted) check
        """

        return False  # not perfect but at least show where is the issue

if __name__ == "__main__":
    current_directory = os.getcwd()
    check_build_context_usage(current_directory)
    print("BuildContext check complete.")