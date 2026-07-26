#ifndef TEST_PLATFORM_H
#define TEST_PLATFORM_H

#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

#include "tlm_axi_adapter.h"
#include "../../tarea3_vp/vp_accel/rgb_to_gray.h"

class TestPlatform
{
public:
    explicit TestPlatform(TlmAxiAdapter& adapter)
        : adapter_(adapter),
          state_(State::Start),
          word_index_(0),
          verified_pixels_(0),
          finished_(false),
          passed_(false)
    {
    }

    void service()
    {
        adapter_.service();

        switch (state_) {
        case State::Start:
            start_test();
            break;

        case State::LoadInputStart:
            if (adapter_.begin_write_word(
                    INPUT_ADDR + static_cast<std::uint32_t>(4u * word_index_),
                    pack_word(rgb_, word_index_))) {
                state_ = State::LoadInputWait;
            }
            break;

        case State::LoadInputWait:
            if (!consume_write_completion("carga RGB")) {
                break;
            }
            ++word_index_;
            report_progress("Cargando RGB en RAM", word_index_, input_words());
            if (word_index_ == input_words()) {
                build_gray_model();
                word_index_ = 0;
                state_ = State::WriteOutputStart;
            } else {
                state_ = State::LoadInputStart;
            }
            break;

        case State::WriteOutputStart:
            if (adapter_.begin_write_word(
                    OUTPUT_ADDR + static_cast<std::uint32_t>(4u * word_index_),
                    pack_word(gray_model_, word_index_))) {
                state_ = State::WriteOutputWait;
            }
            break;

        case State::WriteOutputWait:
            if (!consume_write_completion("escritura de salida gris")) {
                break;
            }
            ++word_index_;
            report_progress("Escribiendo gris en RAM", word_index_, output_words());
            if (word_index_ == output_words()) {
                word_index_ = 0;
                state_ = State::ReadOutputStart;
            } else {
                state_ = State::WriteOutputStart;
            }
            break;

        case State::ReadOutputStart:
            if (adapter_.begin_read_word(
                    OUTPUT_ADDR + static_cast<std::uint32_t>(4u * word_index_))) {
                state_ = State::ReadOutputWait;
            }
            break;

        case State::ReadOutputWait:
            if (!adapter_.completed()) {
                break;
            }
            if (!adapter_.succeeded() || !adapter_.is_read_result()) {
                fail("fallo la lectura AXI de la salida gris");
                break;
            }
            unpack_and_verify_word(word_index_, adapter_.read_data());
            adapter_.clear_completion();
            ++word_index_;
            report_progress("Leyendo gris desde RAM", word_index_, output_words());
            if (word_index_ == output_words()) {
                finish_test();
            } else {
                state_ = State::ReadOutputStart;
            }
            break;

        case State::Finished:
        case State::Failed:
            break;
        }
    }

    bool finished() const { return finished_; }
    bool passed() const { return passed_; }

private:
    enum class State {
        Start,
        LoadInputStart,
        LoadInputWait,
        WriteOutputStart,
        WriteOutputWait,
        ReadOutputStart,
        ReadOutputWait,
        Finished,
        Failed
    };

    static constexpr std::size_t WIDTH = 1920;
    static constexpr std::size_t HEIGHT = 1080;
    static constexpr std::size_t PIXELS = WIDTH * HEIGHT;
    static constexpr std::size_t RGB_BYTES = PIXELS * 3;

    // La entrada ocupa 6 220 800 bytes desde 0x00000000.
    // La salida comienza en 8 MiB y ocupa 2 073 600 bytes.
    static constexpr std::uint32_t INPUT_ADDR = 0x00000000u;
    static constexpr std::uint32_t OUTPUT_ADDR = 0x00800000u;
    static constexpr std::size_t PROGRESS_INTERVAL_WORDS = 100000;

    TlmAxiAdapter& adapter_;
    State state_;
    std::size_t word_index_;
    std::size_t verified_pixels_;
    bool finished_;
    bool passed_;

    std::string project_root_;
    std::vector<unsigned char> rgb_;
    std::vector<unsigned char> gray_model_;
    std::vector<unsigned char> gray_readback_;

    static std::size_t words_for_bytes(std::size_t bytes)
    {
        return (bytes + 3u) / 4u;
    }

    std::size_t input_words() const
    {
        return words_for_bytes(rgb_.size());
    }

    std::size_t output_words() const
    {
        return words_for_bytes(gray_model_.size());
    }

    void start_test()
    {
        std::cout << std::endl
                  << "========================================" << std::endl
                  << " CARGA DE IMAGEN RGB POR DPI + AXI" << std::endl
                  << "========================================" << std::endl;

        const char* root = std::getenv("TAREA3_ROOT");
        if (root == nullptr || root[0] == '\0') {
            fail("no se definio la variable TAREA3_ROOT");
            return;
        }
        project_root_ = root;

        try {
            load_rgb_file(project_root_ + "/input/sapo_perro.rgb");
        }
        catch (const std::exception& error) {
            fail(error.what());
            return;
        }

        gray_model_.assign(PIXELS, 0);
        gray_readback_.assign(PIXELS, 0);

        std::cout << "[IMAGEN] Entrada: "
                  << project_root_ << "/input/sapo_perro.rgb" << std::endl
                  << "[IMAGEN] Resolucion: " << WIDTH << "x" << HEIGHT << std::endl
                  << "[IMAGEN] Bytes RGB: " << rgb_.size() << std::endl
                  << "[IMAGEN] Direccion RGB RAM: 0x" << std::hex << INPUT_ADDR
                  << std::endl
                  << "[IMAGEN] Direccion gris RAM: 0x" << OUTPUT_ADDR
                  << std::dec << std::endl;

        word_index_ = 0;
        state_ = State::LoadInputStart;
    }

    void load_rgb_file(const std::string& path)
    {
        std::ifstream input(path.c_str(), std::ios::binary | std::ios::ate);
        if (!input) {
            throw std::runtime_error("no se pudo abrir input/sapo_perro.rgb");
        }

        const std::ifstream::pos_type end = input.tellg();
        if (end < 0) {
            throw std::runtime_error("no se pudo determinar el tamano del RGB");
        }

        const std::size_t size = static_cast<std::size_t>(end);
        if (size != RGB_BYTES) {
            throw std::runtime_error(
                "sapo_perro.rgb no tiene 1920x1080x3 bytes (6220800)"
            );
        }

        rgb_.resize(size);
        input.seekg(0, std::ios::beg);
        input.read(reinterpret_cast<char*>(rgb_.data()),
                   static_cast<std::streamsize>(rgb_.size()));

        if (!input) {
            throw std::runtime_error("lectura incompleta de sapo_perro.rgb");
        }
    }

    static std::uint32_t pack_word(
        const std::vector<unsigned char>& bytes,
        std::size_t word_index)
    {
        std::uint32_t value = 0;
        const std::size_t base = word_index * 4u;
        for (std::size_t i = 0; i < 4u; ++i) {
            const std::size_t index = base + i;
            if (index < bytes.size()) {
                value |= static_cast<std::uint32_t>(bytes[index]) << (8u * i);
            }
        }
        return value;
    }

    void build_gray_model()
    {
        std::cout << "[IMAGEN] Carga RGB finalizada. Calculando escala de grises..."
                  << std::endl;

        for (std::size_t i = 0; i < PIXELS; ++i) {
            gray_model_[i] = rgb_to_gray(
                rgb_[3u * i],
                rgb_[3u * i + 1u],
                rgb_[3u * i + 2u]
            );
        }
    }

    bool consume_write_completion(const char* operation)
    {
        if (!adapter_.completed()) {
            return false;
        }
        if (!adapter_.succeeded()) {
            std::string message("fallo AXI durante ");
            message += operation;
            fail(message.c_str());
            return false;
        }
        adapter_.clear_completion();
        return true;
    }

    void unpack_and_verify_word(std::size_t word, std::uint32_t value)
    {
        const std::size_t base = word * 4u;
        for (std::size_t i = 0; i < 4u; ++i) {
            const std::size_t index = base + i;
            if (index >= gray_readback_.size()) {
                break;
            }
            const unsigned char byte = static_cast<unsigned char>(
                (value >> (8u * i)) & 0xFFu
            );
            gray_readback_[index] = byte;
            if (byte == gray_model_[index]) {
                ++verified_pixels_;
            }
        }
    }

    void report_progress(
        const char* label,
        std::size_t completed_words,
        std::size_t total_words) const
    {
        if (completed_words == total_words ||
            (completed_words % PROGRESS_INTERVAL_WORDS) == 0u) {
            const double percent = total_words == 0
                ? 100.0
                : (100.0 * static_cast<double>(completed_words) /
                   static_cast<double>(total_words));
            std::cout << "[PROGRESO] " << label << ": "
                      << completed_words << "/" << total_words
                      << " palabras (" << percent << " %)" << std::endl;
        }
    }

    void write_pgm(const std::string& path)
    {
        std::ofstream output(path.c_str(), std::ios::binary);
        if (!output) {
            throw std::runtime_error("no se pudo crear output/sapo_perro.pgm");
        }

        output << "P5\n" << WIDTH << " " << HEIGHT << "\n255\n";
        output.write(
            reinterpret_cast<const char*>(gray_readback_.data()),
            static_cast<std::streamsize>(gray_readback_.size())
        );

        if (!output) {
            throw std::runtime_error("fallo al escribir output/sapo_perro.pgm");
        }
    }

    void finish_test()
    {
        passed_ = (verified_pixels_ == PIXELS);

        if (passed_) {
            try {
                write_pgm(project_root_ + "/output/sapo_perro.pgm");
            }
            catch (const std::exception& error) {
                fail(error.what());
                return;
            }
        }

        finished_ = true;
        state_ = passed_ ? State::Finished : State::Failed;

        std::cout << "[TEST] Pixeles verificados: "
                  << verified_pixels_ << "/" << PIXELS << std::endl;
        if (passed_) {
            std::cout << "[TEST] IMAGE_AXI_LOAD_PASS" << std::endl
                      << "[IMAGEN] Salida: "
                      << project_root_ << "/output/sapo_perro.pgm"
                      << std::endl;
        } else {
            std::cout << "[TEST] IMAGE_AXI_LOAD_FAIL" << std::endl;
        }
    }

    void fail(const char* reason)
    {
        std::cerr << "[TEST] ERROR: " << reason << std::endl;
        passed_ = false;
        finished_ = true;
        state_ = State::Failed;
    }
};

#endif
