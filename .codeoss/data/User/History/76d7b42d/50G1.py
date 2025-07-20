import pandas as pd
import numpy as np
from ollamafreeapi import OllamaFreeAPI
import os
import time
from pathlib import Path

def read_csv(file_path):
    """Read data from CSV with automatic encoding detection"""
    try:
        return pd.read_csv(file_path)
    except UnicodeDecodeError:
        return pd.read_csv(file_path, encoding='latin1')

def auto_output_path(input_path):
    """Generate organized output directory structure"""
    input_path = Path(input_path)
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    output_dir = input_path.parent / "processed_results" / timestamp
    output_dir.mkdir(parents=True, exist_ok=True)
    return {
        'data': str(output_dir / f"{input_path.stem}_processed.csv"),
        'stats': str(output_dir / f"{input_path.stem}_statistics.txt"),
        'insights': str(output_dir / f"{input_path.stem}_insights.txt")
    }

def select_fastest_model(client):
    """Auto-select model based on speed benchmarks"""
    available_models = client.list_models()
    preferred_order = ['phi3:mini', 'mistral:latest', 'llama3:8b']
    
    for model in preferred_order:
        if model in available_models:
            print(f"\n✨ Auto-selected fastest available model: {model}")
            return model
    
    return available_models[0]

def generate_data_description(df):
    """Create comprehensive data profile"""
    description = []
    
    # Basic stats
    description.append("📊 DATA DESCRIPTION REPORT")
    description.append(f"\n📂 Shape: {df.shape[0]} rows x {df.shape[1]} columns")
    
    # Data types
    type_counts = df.dtypes.value_counts().to_string()
    description.append(f"\n🔧 Data Types:\n{type_counts}")
    
    # Missing values
    missing = df.isnull().sum()
    if missing.sum() > 0:
        description.append("\n❌ Missing Values:")
        description.append(missing[missing > 0].to_string())
    else:
        description.append("\n✅ No missing values detected")
    
    # Numeric stats
    numeric_cols = df.select_dtypes(include=np.number).columns
    if len(numeric_cols) > 0:
        description.append("\n🧮 Numeric Columns Statistics:")
        description.append(df[numeric_cols].describe().to_string())
    
    # Categorical stats
    categorical_cols = df.select_dtypes(include='object').columns
    if len(categorical_cols) > 0:
        description.append("\n🔤 Categorical Columns Statistics:")
        for col in categorical_cols:
            top_values = df[col].value_counts().nlargest(5)
            description.append(f"\n{col} (Top {len(top_values)} values):\n{top_values.to_string()}")
    
    return '\n'.join(description)

def analyze_with_llm(client, model, df):
    """Batch process data for efficiency"""
    results = []
    
    # Process in batches of 5 rows
    batch_size = 5
    total_batches = (len(df) + batch_size - 1) // batch_size
    
    print(f"\n🚀 Processing {len(df)} rows in {total_batches} batches...")
    
    for i in range(0, len(df), batch_size):
        batch = df.iloc[i:i+batch_size]
        
        prompt = f"""
        Analyze this batch of {len(batch)} records and provide:
        - Key observations about patterns/outliers
        - Most interesting findings (limit to 3-5 points)
        - Any data quality issues noticed
        
        Data:\n{batch.to_string()}
        """
        
        try:
            response = client.chat(model_name=model, 
                                prompt=prompt,
                                temperature=0.1)  # More factual responses
            results.extend([response] * len(batch))
            print(f"✅ Processed batch {i//batch_size + 1}/{total_batches}")
        except Exception as e:
            print(f"⚠️ Error in batch {i//batch_size + 1}: {str(e)[:100]}...")
            results.extend(["Analysis failed"] * len(batch))
    
    return results

def main():
    print("\n" + "="*50)
    print("📈 SMART CSV ANALYZER WITH AI")
    print("="*50)
    
    # Initialize client
    client = OllamaFreeAPI()
    
    # Specify the CSV file name
    file_path = "Data.csv"
    
    # Check if the file exists
    if not os.path.exists(file_path):
        print("⚠️ File not found. Please ensure 'Data.csv' is in the current directory.")
        return
    
    # Load data
    print("\n🔍 Loading and analyzing data...")
    df = read_csv(file_path)
    if df.empty:
        print("❌ Empty file detected")
        return
    
    # Select the best model
    model = select_fastest_model(client)
    
    # Generate paths
    paths = auto_output_path(file_path)
    
    # Create data description
    with open(paths['stats'], 'w') as f:
        f.write(generate_data_description(df))
    
    # Get AI insights
    print("\n🧠 Generating advanced insights with AI...")
    df['AI_Insights'] = analyze_with_llm(client, model, df.copy())
    
    # Save results
    df.to_csv(paths['data'], index=False)
    
    # Create summary insights
    with open(paths['insights'], 'w') as f:
        f.write("\nTOP INSIGHTS ACROSS ALL DATA:\n")
        f.write("\n".join([f"- {insight}" for insight in 
                         df['AI_Insights'].drop_duplicates().values[:5]]))
    
    # Final report
    print("\n" + "="*50)
    print("🎉 ANALYSIS COMPLETE")
    print("="*50)
    print(f"\n📊 Data Description: {paths['stats']}")
    print(f"💡 Key Insights: {paths['insights']}")
    print(f"🔍 Processed Data: {paths['data']}")
    print("\nTip: For large files (>10k rows), consider analyzing samples first")

if __name__ == "__main__":
    main()
