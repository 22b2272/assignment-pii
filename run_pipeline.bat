@echo off
echo =========================================
echo PII NER Pipeline - Complete Workflow
echo =========================================

REM Step 1: Generate additional training data
echo.
echo Step 1: Generating additional training data...
py data_generator.py

REM Step 2: Combine original and generated data
echo.
echo Step 2: Combining datasets...

REM Check if files exist and combine them
if exist "data\train.jsonl" (
    copy "data\train.jsonl" "data\train_combined.jsonl" >nul
    echo ✓ Added original train data
) else (
    echo ⚠ data\train.jsonl not found
    type nul > "data\train_combined.jsonl"
)

if exist "train_generated.jsonl" (
    type "train_generated.jsonl" >> "data\train_combined.jsonl"
    echo ✓ Added generated train data
)

if exist "data\dev.jsonl" (
    copy "data\dev.jsonl" "data\dev_combined.jsonl" >nul
    echo ✓ Added original dev data
) else (
    echo ⚠ data\dev.jsonl not found
    type nul > "data\dev_combined.jsonl"
)

if exist "dev_generated.jsonl" (
    type "dev_generated.jsonl" >> "data\dev_combined.jsonl"
    echo ✓ Added generated dev data
)

REM Count lines in combined files
for /f %%i in ('type "data\train_combined.jsonl" 2^>nul ^| find /c /v ""') do set train_count=%%i
for /f %%i in ('type "data\dev_combined.jsonl" 2^>nul ^| find /c /v ""') do set dev_count=%%i

echo Training set: %train_count% examples
echo Dev set: %dev_count% examples

REM Step 3: Train the model
echo.
echo Step 3: Training model...
py src\train.py --model_name distilbert-base-uncased --train data\train_combined.jsonl --dev data\dev_combined.jsonl --out_dir out --epochs 4 --batch_size 16 --lr 3e-5 --max_length 128

REM Step 4: Run predictions on dev set
echo.
echo Step 4: Running predictions on dev set...
py src\predict.py --model_dir out --input data\dev_combined.jsonl --output out\dev_pred.json

REM Step 5: Evaluate on dev set
echo.
echo Step 5: Evaluating on dev set...
py src\eval_span_f1.py --gold data\dev_combined.jsonl --pred out\dev_pred.json

REM Step 6: Run predictions on stress set
echo.
echo Step 6: Running predictions on stress set...
py src\predict.py --model_dir out --input data\stress.jsonl --output out\stress_pred.json

REM Step 7: Evaluate on stress set
echo.
echo Step 7: Evaluating on stress set...
py src\eval_span_f1.py --gold data\stress.jsonl --pred out\stress_pred.json

REM Step 8: Measure latency
echo.
echo Step 8: Measuring latency...
py src\measure_latency.py --model_dir out --input data\dev_combined.jsonl --runs 50

REM Step 9: Generate predictions on test set
echo.
echo Step 9: Generating predictions on test set...
if exist "data\test.jsonl" (
    py src\predict.py --model_dir out --input data\test.jsonl --output out\test_pred.json
    echo ✓ Test predictions generated
) else (
    echo ⚠ test.jsonl not found, skipping test predictions
)

echo.
echo =========================================
echo Pipeline complete!
echo =========================================
echo.
echo Results summary:
echo - Model: out/
echo - Dev predictions: out\dev_pred.json
echo - Stress predictions: out\stress_pred.json
echo - Test predictions: out\test_pred.json

pause