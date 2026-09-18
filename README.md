# ComfyUI Qwen3‑VL Batch Captioner

A stable, API‑driven batch captioning pipeline for **ComfyUI + Qwen3‑VL**, designed for dataset creation (LoRA, VLM, SDXL training).  
This PowerShell script sends images one‑by‑one to ComfyUI, waits for each job to finish using the `/queue` API, and saves captions using the same filename as the image.

It is ideal for large datasets, headless servers, and automated workflows where the ComfyUI UI may freeze under heavy load.

---

## ✨ Features

- Batch captioning via ComfyUI API  
- Accurate throttling using `/queue`  
- Trigger word support  
- Perfect filename alignment  
- Stable with Qwen3‑VL  
- Fully commented PowerShell script  
- GitHub‑friendly structure  

---

## 📦 Requirements

### 1. ComfyUI Installed
Any standard ComfyUI installation works.  
Headless mode is recommended for large batches:

```python
python main.py --listen --no-gui
```

### 2. Required Model

Place the Qwen3‑VL text encoder model here: ComfyUI/models/text_encoders/qwen3vl_4b_fp8_scaled.safetensors. Use this download command to retrieve the file.

```python
cd /root/ComfyUI/models/text_encoders && wget --header "Authorization: Bearer [HFKEY]" https://huggingface.co/Comfy-Org/Qwen3-VL/resolve/main/text_encoders/qwen3vl_4b_fp8_scaled.safetensors
```
This model is required for the CLIPLoader node used in caption generation.

### 3. Required Custom Nodes

Install the following into:

```python
ComfyUI/custom_nodes/
```

#### A. ComfyUI-batching-nodes  
Used for stable batch handling and queue‑safe execution.  
Source:  
https://github.com/Hahihula/ComfyUI-batching-nodes

#### B. WAS Node Suite (Save Text File node)  
Provides the `Save Text File` node used to write captions.  
Source:  
https://github.com/WASasquatch/was-node-suite-comfyui

### 4. Images must exist on the ComfyUI server

Your PowerShell script loops through images locally,  
but ComfyUI loads images from its own filesystem:


```python
/root/ComfyUI/input/
```

Ensure your images are uploaded there.

---

##  Usage

Run the script:

/Invoke-ComfyCaption.ps1 -ImageFolder "G:\training\scripts\images" -TriggerWord "RedHairedWoman_f1"

### Parameters

| Parameter      | Description |
|----------------|-------------|
| `ImageFolder`  | Local folder containing images to iterate over |
| `TriggerWord`  | Phrase inserted at the start of every caption |

### Example caption output

When generating captions for character‑based LoRA training, the script prepends a trigger word to every caption. This trigger word acts as the identity token the model will later associate with a specific person or character.

For example, if your trigger word is: 'RedHairedWoman_f1'

```python
RedHairedWoman_f1 is standing beside a bicycle on a quiet street...
```
Why this matters
The purpose of using a trigger word is to teach the image generation model that all images containing this character share the same identity. By repeatedly seeing the same trigger word across many images of the same red‑haired woman, the LoRA learns:

-her hair color

-her facial structure

-her proportions

-her style

-her overall appearance

This ensures the LoRA produces consistent results and recognizes the character as a distinct visual identity.


Later, when generating images, you can reliably summon this character by prompting with: any variation of the character but include RedHairedWoman_f1.
---

## 📜 Script Overview

The script performs:

1. Enumerates images in a local folder  
2. Builds a JSON payload for ComfyUI  
3. Sends one image at a time to `/prompt`  
4. Polls `/queue` until ComfyUI finishes  
5. Saves caption as `Caption0.txt`, `Caption1.txt`, etc.  
6. Moves to the next image  

This ensures maximum stability even for large datasets.

---

## 🧠 Why `/queue` Instead of `/history`?

ComfyUI’s `/history` only records jobs that produce **image outputs**.  
Text‑only workflows (like Qwen3‑VL captioning) often produce **no history entries**, causing scripts to wait forever.

The `/queue` endpoint always reflects the real backend state:

```python
queue_running = []
queue_pending = []
```

When both are empty → the job is finished.

This makes `/queue` the correct throttling method.

---

## 📁 Output Structure

```python
output/
├── Caption0.txt
├── Caption1.txt
├── Caption2.txt
└── ...
```

 
Each caption corresponds exactly to its image:

```python
Caption0.png → Caption0.txt
Caption1.png → Caption1.txt
```

Perfect for dataset training.

---

## 🐛 Troubleshooting

### UI freezes during large batches  
Expected.  
Backend continues running normally.  
Use headless mode for maximum stability.

### “Image model required” or CLIPLoader errors  
Ensure:

```python
ComfyUI/models/text_encoders/qwen3vl_4b_fp8_scaled.safetensors
```


exists.

### PyAV decode warnings  
Harmless.  
ComfyUI probes video inputs even when not used.

---

## 📄 License

Free to use without restrictions.

---

## 🎉 Final Notes

This script is built for **real dataset production**, not demos.  
It’s stable, predictable, and handles Qwen3‑VL’s quirks gracefully.








