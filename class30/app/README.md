# Flask Calculator & Tools

A simple Flask web application featuring a calculator and useful utility tools, without any database dependencies.

## Features

1. **Calculator** - Perform basic arithmetic operations:
   - Addition
   - Subtraction
   - Multiplication
   - Division
   - Power
   - Modulo

2. **Temperature Converter** - Convert between Celsius and Fahrenheit

3. **String Reverser** - Reverse any text string

4. **Random Number Generator** - Generate random numbers within a specified range

## Project Structure

```
app/
├── app.py              # Main Flask application
├── templates/
│   └── index.html      # Single page HTML template
├── tests/
│   └── test_app.py     # Unit tests
├── requirements.txt    # Python dependencies
├── Dockerfile          # Docker configuration
└── README.md          # This file
```

## Running Locally

### Prerequisites
- Python 3.11 or higher
- pip

### Installation

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Run the application:
```bash
python app.py
```

3. Open your browser and navigate to:
```
http://localhost:5000
```

## Running Tests

Run the unit tests with:

```bash
python -m pytest tests/test_app.py -v
```

Or using unittest:

```bash
python tests/test_app.py
```

## Running with Docker

### Build the Docker image:

```bash
docker build -t flask-calculator .
```

### Run the container:

```bash
docker run -p 5000:5000 flask-calculator
```

The application will be available at `http://localhost:5000`

## API Endpoints

- `GET /` - Main page
- `GET /health` - Health check endpoint
- `POST /calculate` - Calculator operations
- `POST /convert-temperature` - Temperature conversion
- `POST /reverse-string` - String reversal
- `POST /random-number` - Random number generation

## Testing

The application includes comprehensive unit tests covering:
- All calculator operations
- Temperature conversions
- String reversal
- Random number generation
- Error handling
- Edge cases

## Technologies Used

- **Flask** - Web framework
- **HTML/CSS/JavaScript** - Frontend
- **Python unittest** - Testing framework
- **Docker** - Containerization
