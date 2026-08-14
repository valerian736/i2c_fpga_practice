#include <stdio.h>

#include "driver/i2c_master.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"

static const gpio_num_t sda = 17;
static const gpio_num_t scl = 16;
static const i2c_port_num_t i2c_channel = 0;
static const uint16_t address = 0x38;
// static const uint8_t aht_regs_temp = 0x00;

i2c_master_bus_handle_t i2c_handle;
i2c_master_dev_handle_t aht10_handler;

static const char* TAG = "aht10";

esp_err_t init_i2c() {
    i2c_master_bus_config_t i2c_config = {.clk_source = I2C_CLK_SRC_DEFAULT,
                                          .i2c_port = i2c_channel,
                                          .scl_io_num = scl,
                                          .sda_io_num = sda,
                                          .glitch_ignore_cnt = 7,
                                          .flags.enable_internal_pullup = false

    };

    return i2c_new_master_bus(&i2c_config, &i2c_handle);
};

esp_err_t init_aht10() {
    i2c_device_config_t aht10_config = {.scl_speed_hz = 100000,
                                        .device_address = address,
                                        .dev_addr_length = I2C_ADDR_BIT_LEN_7};
    esp_err_t ret;

    ret = i2c_master_bus_add_device(i2c_handle, &aht10_config, &aht10_handler);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "aht10 failed to initialize");
        return ret;
    }

    uint8_t command[3] = {0xE1, 0x08, 0x00};

    ret = i2c_master_transmit(aht10_handler, command, sizeof(command), 1000);

    vTaskDelay(pdMS_TO_TICKS(100));

    return ret;
};

esp_err_t aht10_reset() {
    esp_err_t ret;
    uint8_t reset_addr = 0xBA;

    ret = i2c_master_transmit(aht10_handler, &reset_addr, sizeof(reset_addr),
                              1000);

    return ret;
}

esp_err_t aht10_read_vals(uint8_t* data) {
    uint8_t trigger[3] = {0xAC, 0x33, 0x00};
    esp_err_t err;

    err = i2c_master_transmit(aht10_handler, trigger, sizeof(trigger), 10000);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "i2c failed to transmit");
    }

    for (size_t i = 0; i < 10; i++) {
        vTaskDelay(pdMS_TO_TICKS(10));
        esp_err_t ret =
            //i2c_master_receive(aht10_handler, data, 6, 1000);
            i2c_master_transmit_receive(aht10_handler, trigger, sizeof(trigger), data, 6, 1000);
        if (ret != ESP_OK) {
            ESP_LOGE(TAG, "i2c receive failed");
            return ret;
        }

        if (!(data[0] & 0x80)) {
            break;
        }

        if (i == 9) {
            ESP_LOGE(TAG, "i2c timeout issue");
            return ESP_ERR_TIMEOUT;
        }
    }

    return ESP_OK;
};

/* @brief convert raw byte infto humidity and temperature data in celcius. 6 byte: 1 status byte, 2 hum and temp byte, 1 byte for both devided to 2 nibble
with total of 20 bit. 000000000000[0000000000000000][0000] is the initial uint32 variable. in case of humidity the first part of the expression "data[1] << 12" shift the first byte of the datato the right by 12 bits, 
the uint32 data will look like this 000000000000[{data[1]}00000000][0000].
the second part of the expression deals with the second byte of humidity leading to this uint32 tp be 000000000000[{data[1]}{data[2]}][0000]. finally, the third expression grab the humidity nibble of the conjoined byte.
*/
esp_err_t aht10_value_conversion(uint8_t* data) {
    if (data[0] & 0x80) {
        ESP_LOGE(TAG, "aht10 data invalid");
        return ESP_ERR_INVALID_STATE;
    }

    uint32_t s_rh =
        ((uint32_t)data[1] << 12) | ((uint32_t)data[2] << 4) | (data[3] >> 4);
    uint32_t s_t =
        (((uint32_t)data[3] & 0x0F) << 16) | ((uint32_t)data[4] << 8) | data[5];
        /* 00000000 11111111 */
    
    float humidity = (s_rh / 1048576.0f) * 100.0f;
    float temperature = (s_t / 1048576.0f) * 200.0f - 50.0f;

    ESP_LOGI(TAG, "Hum: %.2f Temp: %.2f", humidity, temperature);

    return ESP_OK;
};

void app_main(void) {
    // init i2c
    init_i2c();

    // init aht10
    init_aht10();

    while (true) {
        // aht10 read vals

        uint8_t data[6];
        aht10_read_vals(data);
        ESP_LOGI(TAG, "data %x %x %X %X %X %X", data[0], data[1], data[2],
                 data[3], data[4], data[5]);

        aht10_value_conversion(data);

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}