// Implementation of CPU-mining
// Author: Evgeniy Sukhomlinov
// 2018

// Licensed under GNU General Public License, Version 3. See the LICENSE file.

#include "XCpuMiner.h"
#include <iostream>
#include "Core/Log.h"
#include "Utils/CpuInfo.h"

unsigned XCpuMiner::_numInstances = 0;

XCpuMiner::XCpuMiner(unsigned index, XTaskProcessor* taskProcessor)
    :Miner("cpu-", index, taskProcessor)
{
}

XCpuMiner::~XCpuMiner()
{
}

void XCpuMiner::WorkLoop()
{
    xdag_hash_t hash;
    xdag_field last;
    uint64_t prevTaskIndex = 0;
    uint64_t nonce;
    int iterations = 256;
	uint64_t randomxHashIput[8];

    while(true)
    {
        XTaskWrapper* taskWrapper = GetTask();
        //TODO: move this check higher (before threads creation) in order to remove spam on startup
        if(taskWrapper == NULL)
        {
            clog(LogChannel) << "No work. Pause for 3 s.";
            std::this_thread::sleep_for(std::chrono::seconds(3));
            continue;
        }

        if(taskWrapper->GetIndex() != prevTaskIndex)
        {
            prevTaskIndex = taskWrapper->GetIndex();
            memcpy(last.data, taskWrapper->GetTask()->nonce.data, sizeof(xdag_hash_t));
            nonce = last.amount + _index;
        }
		memcpy(randomxHashIput, taskWrapper->GetTask()->randomx_input.data, sizeof(xdag_hash_t));
		memcpy(randomxHashIput+4, last.data, sizeof(xdag_hashlow_t));
        //last.amount = XHash::SearchMinNonce(&taskWrapper->GetTask()->ctx, nonce, iterations, _numInstances, hash);
		last.amount = SearchMinNonce(randomxHashIput, &nonce, iterations, _numInstances, hash);
		taskWrapper->SetShare(last.data, hash);

        AddHashCount(iterations);

        // Check if we should stop.
        if(ShouldStop())
        {
            break;
        }
    }
}

HwMonitor XCpuMiner::Hwmon()
{
    HwMonitor hw;
    unsigned int tempC = 0, fanpcnt = 0;

    //TODO??
    hw.tempC = tempC;
    hw.fanP = fanpcnt;
    return hw;
}

void XCpuMiner::ListDevices()
{
    //TODO: multi cpu system?

    std::cout << "Cpu " << CpuInfo::GetNumberOfCpuCores() << " cores";
}

uint64_t XCpuMiner::SearchMinNonce(uint64_t* input, uint64_t* nonce, int iterations, int step, xdag_hash_t hash)
{
	xdag_hash_t currentHash;
	uint64_t minNonce = 0;

	randomx_flags flags = GetFlags();
	randomx_dataset* dataset = GetDataset();

	randomx_vm *vm = randomx_create_vm(flags, NULL, dataset);
	if (vm == nullptr) {
		if ((flags & RANDOMX_FLAG_HARD_AES)) {
			throw std::runtime_error("Cannot create VM with the hardAes options.");
		}
		if ((flags & RANDOMX_FLAG_LARGE_PAGES)) {
			throw std::runtime_error("Cannot create VM with the largePages options.");
		}
		throw std::runtime_error("Cannot create VM");
	}

	memcpy(input + 7, nonce, sizeof(uint64_t));
	randomx_calculate_hash_first(vm, input, sizeof(input));

	for (int i = 0; i < iterations; ++i){
        uint64_t curNonce = *nonce;
        *nonce += step;
		memcpy(input + 7, nonce, sizeof(uint64_t)); // next nonce
		randomx_calculate_hash_next(vm, input, sizeof(input), currentHash); // calc current nonce & prepare next
		if (!i || XHash::CompareHashes(currentHash, hash) < 0)
		{
			memcpy(hash, currentHash, sizeof(xdag_hash_t));
			minNonce = curNonce;
		}			
	}
	randomx_destroy_vm(vm);

	return minNonce;
}