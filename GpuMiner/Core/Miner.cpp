/*
   This file is taken from ethminer project.
*/
/*
 * Evgeniy Sukhomlinov
 * 2018
 */

#include "Miner.h"

XDag::Miner::Miner(std::string const& name, uint32_t index, XTaskProcessor* taskProcessor) :
    Worker(name + std::to_string(index)),
    _index(index),
    _taskProcessor(taskProcessor)
{
}
