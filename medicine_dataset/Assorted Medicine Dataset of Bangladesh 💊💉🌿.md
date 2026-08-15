---
title: "Assorted Medicine Dataset of Bangladesh 💊💉🌿"
source: "https://www.kaggle.com/datasets/ahmedshahriarsakib/assorted-medicine-dataset-of-bangladesh"
author:
published:
created: 2026-08-15
description: "A list of all medicines, generics, indications & med companies of Bangladesh"
tags:
  - "clippings"
---
## About Dataset

## Context

This dataset contains lists of medicines with price, generics, indications, drug classes, dosage forms, and pharmaceutical companies of Bangladesh.  
Data was collected via web scraping using python libraries.

Please check this GitHub repository to know more about it -

### \- https://github.com/ahmedshahriar/bd-medicine-scraper

### Download

kaggle API Command

```bash
!kaggle datasets download -d ahmedshahriarsakib/assorted-medicine-dataset-of-bangladesh
```

## Content

The dataset has 6 CSV files -

1. medicine.csv (21k+ entries)
	- brand name
		- medicine type (allopathic or herbal)
		- generic
		- strength
		- manufacturer
		- package container (**unit price** and pack info)
		- Package Size and **unit price**
2. manufacturer.csv (245 entries)
	- name
3. indication.csv (2000+ entries)
	- name
4. generic.csv (~1700-1800 entries)
	- name
		- monographic link (PDF URL)
		- drug class
		- indication
		- generic details such as "Indication description", "Pharmacology description", "Dosage & Administration description" etc.
5. drug class.csv (452 entries)
	- name
6. dosage form.csv (123 entries)
	- name

NB: Some additional cleaning is needed for **medicine.csv** file, in **"Package Container"** and **"Package Size"** columns to extract package and price information

## Starter Notebook

### Bangladesh Medicine Analytics

## Acknowledgements

Data was scraped from -

- [https://medex.com.bd](https://medex.com.bd/) - A Leading Online Medicine Index & Healthcare Portal of Bangladesh.

Cover Image -  
Photo by [Towfiqu barbhuiya](https://unsplash.com/@towfiqu999999?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)

## Inspiration

- How many medicines/generics/manufacturers/drug classes (approximate amount) are available (active selling) in Bangladesh?
- Which generic has the highest associate number of medicines?
- What are the correlation between medicine price and generics?
- Which pharmaceutical company has the highest number of medicines?
- What is the association between drug classes and generics?
- What is the most available dosage form?

## Usability

info

10.00

## License

[CC0: Public Domain](https://creativecommons.org/publicdomain/zero/1.0/)

## Expected update frequency

Never

## Tags

## Data Explorer

Version 5 (12.54 MB)

- dosage form.csv
- drug class.csv
- generic.csv
- indication.csv
- manufacturer.csv
- medicine.csv
