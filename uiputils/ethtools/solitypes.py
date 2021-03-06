
from .loc_cal import singlelocation, origin_singlelocation, slicelocation, maplocation


class SoliUint256:
    def __init__(self, num):
        self.value = num
        self.bin_value = self.encode()

    def encode(self):
        return self.value

    @staticmethod
    def loc(slot):
        return singlelocation(slot)

    @staticmethod
    def ori_loc(slot):
        return origin_singlelocation(slot)


class SoliUint(SoliUint256):
    def __init__(self, num):
        super().__init__(num)


SoliTypes = {
    'uint': SoliUint,
    'uint256': SoliUint256
}
