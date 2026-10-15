from coefficient_sets import coefficientSets


def checkProperties(coefficients):
    c0, c1, c2, c3, c4 = coefficients

    return {
        "c4EqualsNegativeC0": c4 == -c0,
        "c3EqualsNegativeC1": c3 == -c1,
        "c2IsPowerOfTwo": c2 != 0 and (abs(c2) & (abs(c2) - 1)) == 0
    }


for caseName, coefficients in coefficientSets.items():
    properties = checkProperties(coefficients)

    print(f"\nCase {caseName}")
    print(f"Coefficients: {coefficients}")

    for propertyName, value in properties.items():
        print(f"{propertyName}: {value}")
