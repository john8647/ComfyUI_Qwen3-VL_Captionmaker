<#
.SYNOPSIS
    Batch caption generator for ComfyUI using Qwen3-VL.

.DESCRIPTION
    - Sends one image at a time to ComfyUI via API.
    - Waits until ComfyUI finishes each job using /queue polling.
    - Saves captions using the same filename as the image.
    - Allows a configurable trigger word that is prepended to every caption.
    - Designed for dataset creation (LoRA, VLM, SDXL training).

.PARAMETER ImageFolder
    Local folder containing images to caption.

.PARAMETER TriggerWord
    A phrase inserted at the start of every caption.

.EXAMPLE
    ./Invoke-ComfyCaption.ps1 -ImageFolder "G:\training\scripts\images" -TriggerWord "MyDataset"

# REQUIREMENT:
# Place qwen3vl_4b_fp8_scaled.safetensors into:
#     ComfyUI/models/text_encoders/
#>

param(
    [string]$ImageFolder = "G:\training\scripts\images",
    [string]$TriggerWord = "RedHairedWoman_f1"
)

# ComfyUI API root url and port if needed.
$ComfyURL = "http://localhost:8188"

Write-Host "=== ComfyUI Captioner ==="
Write-Host "Image folder: $ImageFolder"
Write-Host "Trigger word: $TriggerWord"
Write-Host ""

# Load all image files
$Images = Get-ChildItem -Path "$ImageFolder\*" -File -Include *.png, *.jpg, *.jpeg, *.webp, *.bmp, *.gif

if ($Images.Count -eq 0) {
    Write-Host "No images found. Exiting."
    exit
}

foreach ($img in $Images) {

    Write-Host "Submitting job for $($img.Name)"

    # Build caption prompt with trigger word
    $CaptionPrompt = "Write one natural sentence describing the image using flowing descriptive prose, not bullet points, keyword lists, or comma‑separated tags. Begin the caption with the trigger phrase '$TriggerWord' followed immediately by a short description of the subject or style’s fixed defining characteristics such as permanent facial features, hair color or style, distinguishing marks, or consistent stylistic traits. After that, describe all variable elements visible in the image that should not be absorbed into the concept, including background or environment, clothing or outfit, lighting, pose or body position, and main objects. Every visible variable attribute must be clearly described so it is not mistakenly learned as a permanent trait. Use plain, readable natural language rather than technical or opaque tokens. Do not add information that is not visually present, and do not guess emotions or identity. A format example would be: 'RedHairedWoman_f1, a woman with who is wearing a plain white t-shirt and jeans standing by a sofa in the living room.'"
    
    # Build JSON payload for ComfyUI
    $Payload = @{
        "prompt" = @{
            "35" = @{
                "inputs" = @{
                    # IMPORTANT: ComfyUI must load images from its own filesystem
                    "image" = "/root/ComfyUI/input/$($img.Name)"
                }
                "class_type" = "LoadImage"
            }
            "28" = @{
                "inputs" = @{
                    "text" = @("1", 0)
                    "root" = "output"
                    "filename_prefix" = ""
                    "filename_delimiter" = ""
                    "filename_number_padding" = 0
                    "file_extension" = ".txt"
                    "encoding" = "utf-8"
                    # Save caption as Caption0.txt, Caption1.txt, etc.
                    "filename_suffix" = $img.BaseName
                }
                "class_type" = "Save Text File"
            }
            "8" = @{
                "inputs" = @{
                    "resize_type" = "scale shorter dimension"
                    "resize_type.shorter_size" = 512
                    "scale_method" = "nearest-exact"
                    "input" = @("35", 0)
                }
                "class_type" = "ResizeImageMaskNode"
            }
            "4" = @{
                "inputs" = @{
                    "clip_name" = "qwen3vl_4b_fp8_scaled.safetensors"
                    "type" = "stable_diffusion"
                    "device" = "default"
                }
                "class_type" = "CLIPLoader"
            }
            "1" = @{
                "inputs" = @{
                    "prompt" = $CaptionPrompt
                    "max_length" = 120
                    "sampling_mode" = "on"
                    "sampling_mode.temperature" = 0.7
                    "sampling_mode.top_k" = 64
                    "sampling_mode.top_p" = 0.95
                    "sampling_mode.min_p" = 0.05
                    "sampling_mode.repetition_penalty" = 1.05
                    "sampling_mode.seed" = 0
                    "sampling_mode.presence_penalty" = 0
                    "thinking" = $false
                    "use_default_template" = $true
                    "mtp" = "auto"
                    "clip" = @("4", 0)
                    "image" = @("8", 0)
                }
                "class_type" = "TextGenerate"
            }
        }
    } | ConvertTo-Json -Depth 10

    # Submit job to ComfyUI
    $Response = Invoke-RestMethod -Uri "$ComfyURL/prompt" -Method Post -Body $Payload -ContentType "application/json"

    Write-Host "Job submitted. Waiting for completion..."

    # Poll until ComfyUI queue is empty
    while ($true) {
        Start-Sleep -Seconds 2

        $Queue = Invoke-RestMethod -Uri "$ComfyURL/queue" -Method Get

        if ($Queue.queue_running.Count -eq 0 -and $Queue.queue_pending.Count -eq 0) {
            break
        }
    }

    Write-Host "Completed: $($img.Name)"
    Write-Host ""
}

Write-Host "=== All captions completed successfully ==="
