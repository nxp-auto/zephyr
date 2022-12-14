/*
 * Copyright (c) 2017 BayLibre, SAS
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <sys/util.h>
#include <kernel.h>
#include <errno.h>
#include <drivers/i2c.h>
#include <string.h>
#include <drivers/i2c/slave/eeprom.h>

#define LOG_LEVEL CONFIG_I2C_LOG_LEVEL
#include <logging/log.h>
LOG_MODULE_REGISTER(i2c_slave);

struct i2c_eeprom_slave_data {
	struct device *i2c_controller;
	struct i2c_slave_config config;
	u32_t buffer_size;
	u8_t *buffer;
	u32_t buffer_idx;
	bool first_write;
};

struct i2c_eeprom_slave_config {
	char *controller_dev_name;
	u8_t address;
	u32_t buffer_size;
	u8_t *buffer;
};

/* convenience defines */
#define DEV_CFG(dev)							\
	((const struct i2c_eeprom_slave_config * const)			\
		(dev)->config->config_info)
#define DEV_DATA(dev)							\
	((struct i2c_eeprom_slave_data * const)(dev)->driver_data)

int eeprom_slave_program(struct device *dev, u8_t *eeprom_data,
			 unsigned int length)
{
	struct i2c_eeprom_slave_data *data = dev->driver_data;

	if (length > data->buffer_size) {
		return -EINVAL;
	}

	memcpy(data->buffer, eeprom_data, length);

	return 0;
}

int eeprom_slave_read(struct device *dev, u8_t *eeprom_data,
		      unsigned int offset)
{
	struct i2c_eeprom_slave_data *data = dev->driver_data;

	if (!data || offset >= data->buffer_size) {
		return -EINVAL;
	}

	*eeprom_data = data->buffer[offset];

	return 0;
}

static int eeprom_slave_write_requested(struct i2c_slave_config *config)
{
	struct i2c_eeprom_slave_data *data = CONTAINER_OF(config,
						struct i2c_eeprom_slave_data,
						config);

	LOG_DBG("eeprom: write req");

	data->first_write = true;

	return 0;
}

static int eeprom_slave_read_requested(struct i2c_slave_config *config,
				       u8_t *val)
{
	struct i2c_eeprom_slave_data *data = CONTAINER_OF(config,
						struct i2c_eeprom_slave_data,
						config);

	*val = data->buffer[data->buffer_idx];

	LOG_DBG("eeprom: read req, val=0x%x", *val);

	/* Increment will be done in the read_processed callback */

	return 0;
}

static int eeprom_slave_write_received(struct i2c_slave_config *config,
				       u8_t val)
{
	struct i2c_eeprom_slave_data *data = CONTAINER_OF(config,
						struct i2c_eeprom_slave_data,
						config);

	LOG_DBG("eeprom: write done, val=0x%x", val);

	/* In case EEPROM wants to be R/O, return !0 here could trigger
	 * a NACK to the I2C controller, support depends on the
	 * I2C controller support
	 */

	if (data->first_write) {
		data->buffer_idx = val;
		data->first_write = false;
	} else {
		data->buffer[data->buffer_idx++] = val;
	}

	data->buffer_idx = data->buffer_idx % data->buffer_size;

	return 0;
}

static int eeprom_slave_read_processed(struct i2c_slave_config *config,
				       u8_t *val)
{
	struct i2c_eeprom_slave_data *data = CONTAINER_OF(config,
						struct i2c_eeprom_slave_data,
						config);

	/* Increment here */
	data->buffer_idx = (data->buffer_idx + 1) % data->buffer_size;

	*val = data->buffer[data->buffer_idx];

	LOG_DBG("eeprom: read done, val=0x%x", *val);

	/* Increment will be done in the next read_processed callback
	 * In case of STOP, the byte won't be taken in account
	 */

	return 0;
}

static int eeprom_slave_stop(struct i2c_slave_config *config)
{
	struct i2c_eeprom_slave_data *data = CONTAINER_OF(config,
						struct i2c_eeprom_slave_data,
						config);

	LOG_DBG("eeprom: stop");

	data->first_write = true;

	return 0;
}

static int eeprom_slave_register(struct device *dev)
{
	struct i2c_eeprom_slave_data *data = dev->driver_data;

	return i2c_slave_register(data->i2c_controller, &data->config);
}

static int eeprom_slave_unregister(struct device *dev)
{
	struct i2c_eeprom_slave_data *data = dev->driver_data;

	return i2c_slave_unregister(data->i2c_controller, &data->config);
}

static const struct i2c_slave_driver_api api_funcs = {
	.driver_register = eeprom_slave_register,
	.driver_unregister = eeprom_slave_unregister,
};

static const struct i2c_slave_callbacks eeprom_callbacks = {
	.write_requested = eeprom_slave_write_requested,
	.read_requested = eeprom_slave_read_requested,
	.write_received = eeprom_slave_write_received,
	.read_processed = eeprom_slave_read_processed,
	.stop = eeprom_slave_stop,
};

static int i2c_eeprom_slave_init(struct device *dev)
{
	struct i2c_eeprom_slave_data *data = DEV_DATA(dev);
	const struct i2c_eeprom_slave_config *cfg = DEV_CFG(dev);

	data->i2c_controller =
		device_get_binding(cfg->controller_dev_name);
	if (!data->i2c_controller) {
		LOG_ERR("i2c controller not found: %s",
			    cfg->controller_dev_name);
		return -EINVAL;
	}

	data->buffer_size = cfg->buffer_size;
	data->buffer = cfg->buffer;
	data->config.address = cfg->address;
	data->config.callbacks = &eeprom_callbacks;

	return 0;
}

#ifdef DT_ATMEL_AT24_0

static struct i2c_eeprom_slave_data i2c_eeprom_slave_0_dev_data;

static u8_t i2c_eeprom_slave_0_buffer[(DT_INST_0_ATMEL_AT24_SIZE * 1024)];

static const struct i2c_eeprom_slave_config i2c_eeprom_slave_0_cfg = {
	.controller_dev_name = DT_INST_0_ATMEL_AT24_BUS_NAME,
	.address = DT_INST_0_ATMEL_AT24_BASE_ADDRESS,
	.buffer_size = (DT_INST_0_ATMEL_AT24_SIZE * 1024),
	.buffer = i2c_eeprom_slave_0_buffer
};

DEVICE_AND_API_INIT(i2c_eeprom_slave_0, DT_INST_0_ATMEL_AT24_LABEL,
		    &i2c_eeprom_slave_init,
		    &i2c_eeprom_slave_0_dev_data, &i2c_eeprom_slave_0_cfg,
		    POST_KERNEL, CONFIG_I2C_SLAVE_INIT_PRIORITY,
		    &api_funcs);

#endif /* DT_ATMEL_AT24_0 */

#ifdef DT_ATMEL_AT24_1

static struct i2c_eeprom_slave_data i2c_eeprom_slave_1_dev_data;

static u8_t i2c_eeprom_slave_1_buffer[(DT_INST_1_ATMEL_AT24_SIZE * 1024)];

static const struct i2c_eeprom_slave_config i2c_eeprom_slave_1_cfg = {
	.controller_dev_name = DT_INST_1_ATMEL_AT24_BUS_NAME,
	.address = DT_INST_1_ATMEL_AT24_BASE_ADDRESS,
	.buffer_size = (DT_INST_1_ATMEL_AT24_SIZE * 1024),
	.buffer = i2c_eeprom_slave_1_buffer
};

DEVICE_AND_API_INIT(i2c_eeprom_slave_1, DT_INST_1_ATMEL_AT24_LABEL,
		    &i2c_eeprom_slave_init,
		    &i2c_eeprom_slave_1_dev_data, &i2c_eeprom_slave_1_cfg,
		    POST_KERNEL, CONFIG_I2C_SLAVE_INIT_PRIORITY,
		    &api_funcs);

#endif /* DT_ATMEL_AT24_1 */
