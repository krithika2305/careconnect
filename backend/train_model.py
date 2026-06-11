import os
import tensorflow as tf
from tensorflow.keras.preprocessing import image_dataset_from_directory
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, Dropout
from tensorflow.keras.models import Model
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.callbacks import ModelCheckpoint, EarlyStopping

# Configuration
DATASET_DIR = "dataset/AugmentedAlzheimerDataset"
MODEL_SAVE_PATH = "alzheimers_model.h5"
BATCH_SIZE = 32
IMG_SIZE = (128, 128)  # Reduced size to speed up training on 34k images
EPOCHS = 5  # Start with 5 epochs to get a working model quickly

def build_model(num_classes):
    print("Building MobileNetV2 Transfer Learning Model...")
    
    # Base model from MobileNetV2 (weights pre-trained on ImageNet)
    base_model = MobileNetV2(
        weights='imagenet', 
        include_top=False, 
        input_shape=IMG_SIZE + (3,)
    )
    
    # Freeze the base model
    base_model.trainable = False
    
    # Add custom head for our specific classes
    x = base_model.output
    x = GlobalAveragePooling2D()(x)
    x = Dropout(0.2)(x)
    predictions = Dense(num_classes, activation='softmax')(x)
    
    model = Model(inputs=base_model.input, outputs=predictions)
    
    model.compile(
        optimizer=Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    return model

def main():
    print(f"Loading dataset from: {DATASET_DIR}")
    
    if not os.path.exists(DATASET_DIR):
        print(f"Error: Dataset path '{DATASET_DIR}' not found!")
        return

    # Load the training dataset (80% for training)
    train_dataset = image_dataset_from_directory(
        DATASET_DIR,
        validation_split=0.2,
        subset="training",
        seed=123,
        image_size=IMG_SIZE,
        batch_size=BATCH_SIZE
    )

    # Load the validation dataset (20% for validation)
    val_dataset = image_dataset_from_directory(
        DATASET_DIR,
        validation_split=0.2,
        subset="validation",
        seed=123,
        image_size=IMG_SIZE,
        batch_size=BATCH_SIZE
    )

    class_names = train_dataset.class_names
    print(f"Detected classes: {class_names}")

    # Optimize dataset loading performance
    AUTOTUNE = tf.data.AUTOTUNE
    train_dataset = train_dataset.cache().prefetch(buffer_size=AUTOTUNE)
    val_dataset = val_dataset.cache().prefetch(buffer_size=AUTOTUNE)

    # Build and summarize model
    model = build_model(num_classes=len(class_names))
    
    # Callbacks to save the best model and stop early if it stops improving
    checkpoint = ModelCheckpoint(
        MODEL_SAVE_PATH, 
        monitor='val_accuracy', 
        save_best_only=True, 
        mode='max',
        verbose=1
    )
    
    early_stop = EarlyStopping(
        monitor='val_accuracy', 
        patience=2, 
        restore_best_weights=True
    )

    print(f"Starting training for {EPOCHS} epochs...")
    history = model.fit(
        train_dataset,
        validation_data=val_dataset,
        epochs=EPOCHS,
        callbacks=[checkpoint, early_stop]
    )

    print(f"Training complete. Best model saved as '{MODEL_SAVE_PATH}'")

if __name__ == '__main__':
    main()
