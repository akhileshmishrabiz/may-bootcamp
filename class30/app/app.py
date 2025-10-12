from flask import Flask, render_template, request, jsonify
import random

app = Flask(__name__)


@app.route("/")
def index():
    """Render the main page"""
    return render_template("index.html")


@app.route("/calculate", methods=["POST"])
def calculate():
    """Perform calculator operations"""
    try:
        data = request.get_json()
        num1 = float(data.get("num1", 0))
        num2 = float(data.get("num2", 0))
        operation = data.get("operation", "")

        result = None

        if operation == "add":
            result = num1 + num2
        elif operation == "subtract":
            result = num1 - num2
        elif operation == "multiply":
            result = num1 * num2
        elif operation == "divide":
            if num2 == 0:
                return jsonify({"error": "Cannot divide by zero"}), 400
            result = num1 / num2
        elif operation == "power":
            result = num1**num2
        elif operation == "modulo":
            if num2 == 0:
                return jsonify({"error": "Cannot perform modulo with zero"}), 400
            result = num1 % num2
        else:
            return jsonify({"error": "Invalid operation"}), 400

        return jsonify({"result": result})
    except ValueError:
        return jsonify({"error": "Invalid numbers provided"}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/convert-temperature", methods=["POST"])
def convert_temperature():
    """Convert temperature between Celsius and Fahrenheit"""
    try:
        data = request.get_json()
        value = float(data.get("value", 0))
        from_unit = data.get("from", "celsius").lower()

        if from_unit == "celsius":
            result = (value * 9 / 5) + 32
            to_unit = "Fahrenheit"
        elif from_unit == "fahrenheit":
            result = (value - 32) * 5 / 9
            to_unit = "Celsius"
        else:
            return jsonify({"error": "Invalid temperature unit"}), 400

        return jsonify(
            {
                "result": round(result, 2),
                "from_value": value,
                "from_unit": from_unit.capitalize(),
                "to_unit": to_unit,
            }
        )
    except ValueError:
        return jsonify({"error": "Invalid temperature value"}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/reverse-string", methods=["POST"])
def reverse_string():
    """Reverse a string"""
    try:
        data = request.get_json()
        text = data.get("text", "")

        if not text:
            return jsonify({"error": "No text provided"}), 400

        reversed_text = text[::-1]
        return jsonify({"original": text, "reversed": reversed_text})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/random-number", methods=["POST"])
def random_number():
    """Generate a random number within a range"""
    try:
        data = request.get_json()
        min_val = int(data.get("min", 1))
        max_val = int(data.get("max", 100))

        if min_val >= max_val:
            return jsonify({"error": "Minimum must be less than maximum"}), 400

        result = random.randint(min_val, max_val)
        return jsonify({"result": result, "min": min_val, "max": max_val})
    except ValueError:
        return jsonify({"error": "Invalid range values"}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/health")
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
