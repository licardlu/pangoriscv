# SWiM3 Dataset

## Overview

The **SWiM-3** dataset (Solid Waste Mapping) consists of 6,429 annotated images belonging to 10 different waste sub-categories. The dataset was created to aid in solid waste classification and object detection tasks. It contains various waste objects divided into three main categories: **Plastic**, **Paper**, and **Metal**. The images were collected from different real-world environments, ensuring diversity in settings, lighting conditions and object appearances.

<img src="Dataset_Stats/class_distribution.png" alt="Complete Dataset Distribution" width="450"/>

## Data Split Ratio

<div style="display: flex; justify-content: space-between; align-items: center; gap: 10px;">
 <p>Train Set</p>
  <img src="Dataset_Stats/train_Set.png" alt="Train Distribution" width="450"/>
   <p>Validation Set</p>
  <img src="Dataset_Stats/valid_Set.png" alt="Validation Distribution" width="450"/>
   <p>Test Set</p>
  <img src="Dataset_Stats/test_Set.png" alt="Test Distribution" width="450"/>
</div>


## Data Collection and Creation

The images in the **SWiM-3** dataset were collected manually using a smartphone camera. These images were captured from various environments such as households, parks, and public spaces. The dataset includes different types of solid waste objects, which are grouped into three primary categories: **Plastic**, **Paper**, and **Metal**.

### Data Description

The **SWiM-3** dataset is designed specifically for solid waste classification. Below is an overview of the waste categories and their respective classes:

| **Category** | **Class**     | **Description**                                      |
|--------------|---------------|------------------------------------------------------|
| Plastic      | Bottle        | Plastic bottle commonly used for drinks              |
|              | Bottlecap     | Plastic cap used to seal bottles                     |
|              | Straw         | Plastic straw used for drinking                      |
|              | Cup           | Paper cup commonly used for drinks                   |
|              | Plastic       | Misclassified plastic material                       |
| Paper        | Carton        | Paper carton (e.g., milk or juice cartons)           |
|              | Crumpled Paper| Crumpled or crushed paper                           |
|              | Wood          | Wooden pieces or objects                            |
| Metal        | Can           | Metal soft drink can                                |
|              | Metalcap      | Metal bottle cap                                    |
|              | SprayCans      | Spray Cans and Seodorants                          |

## Data Generation and Acquisition

The images in the **SWiM-10** dataset were collected under various lighting conditions and angles to increase the diversity of data. The following environments were used for data collection:

- Households
- Parks and public spaces

### Data Preprocessing

Data preprocessing plays an essential role in optimizing the dataset for training an object detection model. This step includes resizing images, cleaning the dataset by removing blurry images, and normalizing the data to ensure it meets the requirements for model training.

- **Image Resolution:** All images were resized to 640x640 pixels.
- **Cleaning:** Blurry images were manually inspected and removed.
  
### Data Annotation

Each image in the dataset was manually annotated using tools such as **LabelImg**, **Roboflow**, and **CVAT** to create bounding boxes around each waste object. The annotations were made in the **YOLOv8 format**, which includes the coordinates of the bounding boxes and the corresponding class labels.

#### Annotation Tools:
- LabelImg
- Roboflow
- CVAT

### Data Augmentation

Data augmentation techniques were applied to artificially increase the dataset's size and diversity. This includes operations like rotation, flipping, scaling, and brightness adjustments. The following tools were used for data augmentation:
- Python scripts
- Roboflow

### Data Structure

The dataset follows the directory structure outlined below:



### Annotation Format

The dataset includes annotations in the following formats:

#### YOLO Format:

- **<class>:** The class ID or label of the object.
- **<x_center>:** x-coordinate of the object's center relative to the image width.
- **<y_center>:** y-coordinate of the object's center relative to the image height.
- **<width>:** Width of the object relative to the image width.
- **<height>:** Height of the object relative to the image height.

#### Faster R-CNN Format:
- **<class>:** The class ID of the object.
- **<xmin>:** The x-coordinate of the top-left corner of the bounding box.
- **<ymin>:** The y-coordinate of the top-left corner of the bounding box.
- **<xmax>:** The x-coordinate of the bottom-right corner of the bounding box.
- **<ymax>:** The y-coordinate of the bottom-right corner of the bounding box.

### Data Validation

The dataset underwent a validation process to ensure that all images and annotations were correctly formatted and paired. Key validation steps included:

- **File Format Consistency:** Ensuring all images are in JPEG or PNG format.
- **Class Label Integrity:** Verifying that class labels in annotations correspond to the correct categories.
- **Annotation-Image Pairing:** Ensuring each image had a corresponding annotation file.

Errors discovered during validation (such as missing annotations or incorrect bounding boxes) were corrected to ensure dataset quality.

### Results of Validation
After performing validation, the following issues were addressed:

- **Missing Annotations:** Approximately 2% of the images were missing annotations. These images were either manually annotated or removed.
- **Incorrect Bounding Boxes:** A small number of bounding boxes were corrected.
- **Labeling Errors:** Some mislabeling occurred, which was corrected during the validation process.

## Data Splitting

The dataset was split into training, validation, and test sets following an 80-10-10 strategy:

- **Training Set (80%):** Used to train the model.
- **Validation Set (10%):** Used to tune model hyperparameters and prevent overfitting.
- **Test Set (10%):** Used to evaluate the model's performance.

The data was shuffled before splitting to ensure balanced class distribution across all sets.

## License

This dataset is made available for research and educational purposes. Please refer to the LICENSE file for more details.

## 📄 Publication Details

**Title:** SWiM3: Solid Waste Mapping Dataset  

- **Conference:** 2025 5th International Conference on Digital Futures and Transformative Technologies (ICoDT2)  
- **Conference Date:** 17–18 December 2025  
- **Conference Location:** Islamabad, Pakistan  
- **Publisher:** IEEE  
- **Date Added to IEEE Xplore:** 03 February 2026  
- **DOI:** https://doi.org/10.1109/ICoDT269104.2025.11360732  
- **IEEE Xplore Link:** https://ieeexplore.ieee.org/document/11360732  

---

## 📚 Citation

If you use the **SWiM3** dataset in your research, please cite our paper:

``bibtex
@inproceedings{ahmed2025swim3,
  author={Ahmed, M. B. and Razzaq, J. and Razeen, S.},
  title={SWiM3: Solid Waste Mapping Dataset},
  booktitle={2025 5th International Conference on Digital Futures and Transformative Technologies (ICoDT2)},
  year={2025},
  pages={1-6},
  publisher={IEEE},
  doi={10.1109/ICoDT269104.2025.11360732},
  address={Islamabad, Pakistan}
}
