import unittest
import json
import sys
import os

# Add parent directory to path to import app
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import app


class FlaskAppTestCase(unittest.TestCase):
    """Test cases for Flask calculator and tools application"""

    def setUp(self):
        """Set up test client before each test"""
        self.app = app
        self.app.config['TESTING'] = True
        self.client = self.app.test_client()

    def test_index_page(self):
        """Test that the index page loads successfully"""
        response = self.client.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'Flask Calculator & Tools', response.data)

    def test_health_endpoint(self):
        """Test health check endpoint"""
        response = self.client.get('/health')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['status'], 'healthy')

    # Calculator Tests
    def test_calculator_add(self):
        """Test addition operation"""
        response = self.client.post('/calculate',
                                     data=json.dumps({'num1': 5, 'num2': 3, 'operation': 'add'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['result'], 8)

    def test_calculator_subtract(self):
        """Test subtraction operation"""
        response = self.client.post('/calculate',
                                     data=json.dumps({'num1': 10, 'num2': 4, 'operation': 'subtract'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['result'], 6)

    def test_calculator_multiply(self):
        """Test multiplication operation"""
        response = self.client.post('/calculate',
                                     data=json.dumps({'num1': 6, 'num2': 7, 'operation': 'multiply'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['result'], 42)

    def test_calculator_divide(self):
        """Test division operation"""
        response = self.client.post('/calculate',
                                     data=json.dumps({'num1': 20, 'num2': 4, 'operation': 'divide'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['result'], 5)

    def test_calculator_divide_by_zero(self):
        """Test division by zero returns error"""
        response = self.client.post('/calculate',
                                     data=json.dumps({'num1': 10, 'num2': 0, 'operation': 'divide'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 400)
        data = json.loads(response.data)
        self.assertIn('error', data)
        self.assertEqual(data['error'], 'Cannot divide by zero')

    def test_calculator_power(self):
        """Test power operation"""
        response = self.client.post('/calculate',
                                     data=json.dumps({'num1': 2, 'num2': 3, 'operation': 'power'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['result'], 8)

    def test_calculator_modulo(self):
        """Test modulo operation"""
        response = self.client.post('/calculate',
                                     data=json.dumps({'num1': 10, 'num2': 3, 'operation': 'modulo'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['result'], 1)

    def test_calculator_modulo_by_zero(self):
        """Test modulo by zero returns error"""
        response = self.client.post('/calculate',
                                     data=json.dumps({'num1': 10, 'num2': 0, 'operation': 'modulo'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 400)
        data = json.loads(response.data)
        self.assertIn('error', data)

    def test_calculator_invalid_operation(self):
        """Test invalid operation returns error"""
        response = self.client.post('/calculate',
                                     data=json.dumps({'num1': 5, 'num2': 3, 'operation': 'invalid'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 400)
        data = json.loads(response.data)
        self.assertIn('error', data)

    def test_calculator_with_floats(self):
        """Test calculator with floating point numbers"""
        response = self.client.post('/calculate',
                                     data=json.dumps({'num1': 5.5, 'num2': 2.5, 'operation': 'add'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['result'], 8.0)

    def test_calculator_with_negative_numbers(self):
        """Test calculator with negative numbers"""
        response = self.client.post('/calculate',
                                     data=json.dumps({'num1': -5, 'num2': 3, 'operation': 'add'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['result'], -2)

    # Temperature Converter Tests
    def test_celsius_to_fahrenheit(self):
        """Test Celsius to Fahrenheit conversion"""
        response = self.client.post('/convert-temperature',
                                     data=json.dumps({'value': 0, 'from': 'celsius'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['result'], 32)
        self.assertEqual(data['to_unit'], 'Fahrenheit')

    def test_fahrenheit_to_celsius(self):
        """Test Fahrenheit to Celsius conversion"""
        response = self.client.post('/convert-temperature',
                                     data=json.dumps({'value': 32, 'from': 'fahrenheit'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['result'], 0)
        self.assertEqual(data['to_unit'], 'Celsius')

    def test_temperature_conversion_100_celsius(self):
        """Test boiling point conversion"""
        response = self.client.post('/convert-temperature',
                                     data=json.dumps({'value': 100, 'from': 'celsius'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['result'], 212)

    def test_temperature_invalid_unit(self):
        """Test invalid temperature unit returns error"""
        response = self.client.post('/convert-temperature',
                                     data=json.dumps({'value': 100, 'from': 'kelvin'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 400)
        data = json.loads(response.data)
        self.assertIn('error', data)

    # String Reverser Tests
    def test_reverse_simple_string(self):
        """Test reversing a simple string"""
        response = self.client.post('/reverse-string',
                                     data=json.dumps({'text': 'hello'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['reversed'], 'olleh')
        self.assertEqual(data['original'], 'hello')

    def test_reverse_string_with_spaces(self):
        """Test reversing string with spaces"""
        response = self.client.post('/reverse-string',
                                     data=json.dumps({'text': 'hello world'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['reversed'], 'dlrow olleh')

    def test_reverse_string_with_special_chars(self):
        """Test reversing string with special characters"""
        response = self.client.post('/reverse-string',
                                     data=json.dumps({'text': 'Hello! 123'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['reversed'], '321 !olleH')

    def test_reverse_empty_string(self):
        """Test reversing empty string returns error"""
        response = self.client.post('/reverse-string',
                                     data=json.dumps({'text': ''}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 400)
        data = json.loads(response.data)
        self.assertIn('error', data)

    def test_reverse_palindrome(self):
        """Test reversing a palindrome"""
        response = self.client.post('/reverse-string',
                                     data=json.dumps({'text': 'racecar'}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['reversed'], 'racecar')

    # Random Number Generator Tests
    def test_random_number_generation(self):
        """Test random number generation within range"""
        response = self.client.post('/random-number',
                                     data=json.dumps({'min': 1, 'max': 10}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertIn('result', data)
        self.assertGreaterEqual(data['result'], 1)
        self.assertLessEqual(data['result'], 10)

    def test_random_number_large_range(self):
        """Test random number with large range"""
        response = self.client.post('/random-number',
                                     data=json.dumps({'min': 1, 'max': 1000}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertGreaterEqual(data['result'], 1)
        self.assertLessEqual(data['result'], 1000)

    def test_random_number_negative_range(self):
        """Test random number with negative range"""
        response = self.client.post('/random-number',
                                     data=json.dumps({'min': -10, 'max': 10}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertGreaterEqual(data['result'], -10)
        self.assertLessEqual(data['result'], 10)

    def test_random_number_invalid_range(self):
        """Test random number with invalid range (min >= max)"""
        response = self.client.post('/random-number',
                                     data=json.dumps({'min': 10, 'max': 5}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 400)
        data = json.loads(response.data)
        self.assertIn('error', data)

    def test_random_number_equal_min_max(self):
        """Test random number when min equals max"""
        response = self.client.post('/random-number',
                                     data=json.dumps({'min': 5, 'max': 5}),
                                     content_type='application/json')
        self.assertEqual(response.status_code, 400)
        data = json.loads(response.data)
        self.assertIn('error', data)


if __name__ == '__main__':
    unittest.main()
