from pathlib import Path
import random
import sys

projectRoot = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(projectRoot / "python"))

from coefficient_sets import coefficientSets

outputRoot = projectRoot / "results" / "generalization"
numSamples = 1000
randomSeed = 20261011


def saturate12(value):
    return max(-2048, min(2047, value))


def referenceOutput(samples, coefficients):
    history = [0, 0, 0, 0]
    outputs = []

    for sample in samples:
        accumulator = (
            coefficients[0] * sample
            + coefficients[1] * history[0]
            + coefficients[2] * history[1]
            + coefficients[3] * history[2]
            + coefficients[4] * history[3]
        )

        shifted = accumulator >> 10
        outputs.append(saturate12(shifted))

        history = [sample] + history[:3]

    return outputs


def generateSamples(count, seed):
    rng = random.Random(seed)

    # Include boundary values and representative PAM4 levels.
    specialValues = [
        -2048, -2047, -1024, -768, -256,
        -3 * 256, -256, 0, 256, 3 * 256,
        768, 1024, 2046, 2047
    ]

    samples = specialValues[:]

    while len(samples) < count:
        choice = rng.randrange(4)

        if choice == 0:
            samples.append(rng.randint(-2048, 2047))
        elif choice == 1:
            samples.append(rng.choice([-768, -256, 256, 768]))
        elif choice == 2:
            samples.append(rng.choice([-2048, -2047, 2046, 2047]))
        else:
            samples.append(rng.randint(-512, 511))

    return samples[:count]


def main():
    samples = generateSamples(numSamples, randomSeed)

    for caseName in ("B", "C"):
        caseDir = outputRoot / f"case_{caseName}" / "baseline"
        caseDir.mkdir(parents=True, exist_ok=True)

        coefficients = coefficientSets[caseName]
        expected = referenceOutput(samples, coefficients)

        inputPath = caseDir / "input_vectors.txt"
        expectedPath = caseDir / "expected_vectors.txt"

        inputPath.write_text(
            "".join(f"{sample}\n" for sample in samples)
        )
        expectedPath.write_text(
            "".join(f"{value}\n" for value in expected)
        )

        print(f"Case {caseName}: {len(samples)} samples")
        print(f"  Coefficients: {coefficients}")
        print(f"  Inputs:       {inputPath}")
        print(f"  Expected:     {expectedPath}")
        print(f"  Output range: {min(expected)} to {max(expected)}")


if __name__ == "__main__":
    main()
