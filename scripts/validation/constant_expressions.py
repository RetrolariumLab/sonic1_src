"""Resolve numeric AS equates without executing source or treating labels as numbers."""

import ast
import operator
import re

BINARY = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.BitAnd: operator.and_,
    ast.BitOr: operator.or_,
    ast.BitXor: operator.xor,
    ast.LShift: operator.lshift,
    ast.RShift: operator.rshift,
}
UNARY = {ast.UAdd: operator.pos, ast.USub: operator.neg, ast.Invert: operator.invert}


def number(expression, known):
    expression = re.sub(r"\$([0-9a-f]+)", r"0x\1", expression, flags=re.I)
    expression = re.sub(r"\b([0-9][0-9a-f]*)h\b", r"0x\1", expression, flags=re.I)
    expression = re.sub(r"(?<![\w)])%([01]+)", r"0b\1", expression)

    def visit(node, depth=0):
        if depth > 32:
            raise ValueError("Constant expression is too deep")
        if isinstance(node, ast.Constant) and type(node.value) is int:
            result = node.value
        elif isinstance(node, ast.Name):
            result = known[node.id.lower()]
        elif isinstance(node, ast.UnaryOp) and type(node.op) in UNARY:
            result = UNARY[type(node.op)](visit(node.operand, depth + 1))
        elif isinstance(node, ast.BinOp):
            left, right = visit(node.left, depth + 1), visit(node.right, depth + 1)
            if isinstance(node.op, (ast.Div, ast.FloorDiv, ast.Mod)):
                quotient = (abs(left) // abs(right)) * (-1 if (left < 0) != (right < 0) else 1)
                result = left - quotient * right if isinstance(node.op, ast.Mod) else quotient
            elif type(node.op) in BINARY:
                if isinstance(node.op, (ast.LShift, ast.RShift)) and not 0 <= right <= 63:
                    raise ValueError("Constant shift is outside 64 bits")
                result = BINARY[type(node.op)](left, right)
            else:
                raise ValueError("Unsupported constant operator")
        else:
            raise ValueError("Expression is not purely numeric")
        if abs(result) >= 1 << 64:
            raise ValueError("Constant expression exceeds 64 bits")
        return result

    try:
        return visit(ast.parse(expression.strip(), mode="eval").body)
    except (SyntaxError, ValueError, KeyError, ZeroDivisionError, RecursionError):
        return None
