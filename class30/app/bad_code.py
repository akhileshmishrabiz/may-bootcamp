

def calculate_something(x, y, z):
    result = x + y + z
    unused_var = "this is not used"
    another_unused = 123
    return result


class myBadClass:
    def __init__(self, name, age):
        self.name = name
        self.age = age

    def PrintInfo(self):
        print("Name: " + self.name)
        print("Age: " + str(self.age))


def function_with_long_line():
    very_long_string = "This is a very long string that exceeds the recommended line length and should be split into multiple lines for better readability but I'm keeping it all on one line"
    return very_long_string


def badly_formatted_function(a, b, c, d, e, f):
    if a > b:
        if c > d:
            if e > f:
                return True
            else:
                return False
        else:
            return False
    else:
        return False


l = [1, 2, 3, 4, 5]
d = {"key1": "value1", "key2": "value2"}


def foo():
    pass


def bar():
    x = 1 + 2 + 3 + 4 + 5
    y = 10 - 5
    z = x * y
    if x == 15:
        print("x is 15")
    else:
        print("x is not 15")


GLOBAL_VAR = 100


def use_global():
    global GLOBAL_VAR
    GLOBAL_VAR = 200
    print(GLOBAL_VAR)


def compare_values(val1, val2):
    if val1 == None:
        return False
    if val2 == None:
        return False
    return val1 == val2


def bad_exception_handling():
    try:
        x = 1 / 0
    except:
        pass


def lambda_abuse():
    f = lambda x, y, z: x + y + z
    return f(1, 2, 3)
