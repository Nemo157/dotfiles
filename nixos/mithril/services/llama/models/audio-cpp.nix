{ config, fetchHF, ... }: {
  services.llama-swap.models.audio = {
    "supertonic-3" = {
      id = "supertonic-3";
      family = "supertonic";
      path = fetchHF {
        repo = "audio-cpp/audio.cpp-gguf";
        rev = "359189ae3925638d419866d505c180a91815d8b8";
        file = "Supertonic-3-GGUF/supertonic-3-orig.gguf";
        hash = "sha256-r4FEhqC8lRP7Nq+r2bEVWtFPssNqEHrG/+Yuqa2vtmI=";
      };
      task = "tts";
      mode = "streaming";
      load_options = {
        language = "english";
      };
      voice_presets = {
        M1.voice_id = "M1";
        M2.voice_id = "M2";
        M3.voice_id = "M3";
        F1.voice_id = "F1";
        F2.voice_id = "F2";
        F3.voice_id = "F3";
      };
    };

    "voxcpm2" = {
      id = "voxcpm2";
      family = "voxcpm2";
      path = fetchHF {
        repo = "audio-cpp/audio.cpp-gguf";
        rev = "359189ae3925638d419866d505c180a91815d8b8";
        file = "VoxCPM2-GGUF/voxcpm2-orig.gguf";
        hash = "sha256-ExgeAeFdVVyernd5Ym6zlcaTNPFelIyeomXd83q1CxY=";
      };
      task = "tts";
      mode = "streaming";
      load_options = {
        language = "english";
      };
    };

    "omnivoice" = {
      id = "omnivoice";
      family = "omnivoice";
      path = fetchHF {
        repo = "audio-cpp/audio.cpp-gguf";
        rev = "359189ae3925638d419866d505c180a91815d8b8";
        file = "OmniVoice-GGUF/omnivoice-f16.gguf";
        hash = "sha256-dCG2w4c1HSzc5+uLkx+ieXOdYo7yWs1P8gYqcObhq2M=";
      };
      task = "tts";
      mode = "streaming";
      load_options = {
        language = "english";
      };
      voice_presets = {
        # female.instruct = "female, young adult, moderate pitch";
      };
    };
  };
}
